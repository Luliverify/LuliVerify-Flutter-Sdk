import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/luliverify_config.dart';
import '../contracts/input_contract.dart';
import '../contracts/json_contract.dart';
import '../errors/luliverify_exception.dart';
import '../../features/session/workflow_session.dart';
import 'session_transport.dart';

/// One-time grant returned by LuliVerify or a merchant server, never a key.
final class LuliVerifyNativeGrant {
  LuliVerifyNativeGrant.fromJson(Object? json) {
    final data = jsonObject(json);
    sessionId = jsonString(data['sessionId']);
    _ticket = jsonString(data['ticket']);
    if (!RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(sessionId) ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(_ticket) ||
        data['accessChannel'] != 'native') {
      invalidContract();
    }
    final text = jsonString(data['ticketExpiresAt']);
    if (!RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(text)) invalidContract();
    ticketExpiresAt = DateTime.tryParse(text)?.toUtc() ?? invalidContract();
  }
  late final String sessionId;
  late final DateTime ticketExpiresAt;
  late String _ticket;
  bool _consumed = false;
  String _consume() {
    if (_consumed || !ticketExpiresAt.isAfter(DateTime.now())) {
      throw const LuliVerifyException(
        'grant_expired',
        'Start verification again or obtain an authorized resume grant.',
      );
    }
    _consumed = true;
    final ticket = _ticket;
    _ticket = '';
    return ticket;
  }
}

/// Owns its HTTP client and in-memory token. No Origin, cookies or merchant key.
final class LuliVerifyNativeSessionTransport
    implements LuliVerifySessionTransport {
  LuliVerifyNativeSessionTransport._(this.config, this.sessionId, this._client);
  final LuliVerifyConfig config;
  final String sessionId;
  final http.Client _client;
  String? _token;
  bool _closed = false;
  bool _busy = false;
  final Set<Completer<void>> _aborts = {};
  LuliVerifySession? _last;
  LuliVerifySession get initialSession => _last!;

  /// Public mobile launch. The key grants creation only, never account access.
  static Future<Map<String, Object?>> createLaunch({
    required LuliVerifyConfig config,
    required String publishableKey,
    required String releaseId,
    required String idempotencyKey,
    String? customerReference,
    Uri? returnUrl,
    http.Client? client,
  }) async {
    if (!RegExp(r'^lv_pk_[A-Za-z0-9_-]{43}$').hasMatch(publishableKey) ||
        !RegExp(r'^[a-f0-9]{24}$').hasMatch(releaseId) ||
        !RegExp(r'^[A-Za-z0-9_-]{8,100}$').hasMatch(idempotencyKey) ||
        (customerReference != null &&
            (customerReference.isEmpty || customerReference.length > 150))) {
      throw ArgumentError(
        'Use a valid publishable key, release ID and launch reference.',
      );
    }
    final hosted = config.presentation == LuliVerifyPresentation.hostedWeb;
    if (hosted &&
        (returnUrl == null ||
            returnUrl.scheme != 'https' ||
            returnUrl.host.isEmpty ||
            returnUrl.userInfo.isNotEmpty ||
            returnUrl.hasFragment)) {
      throw ArgumentError(
        'Hosted mode requires a registered HTTPS return URL.',
      );
    }
    if (!hosted && returnUrl != null) {
      throw ArgumentError('Native mode does not use a return URL.');
    }
    final transport = LuliVerifyNativeSessionTransport._(
      config,
      '',
      client ?? http.Client(),
    );
    try {
      final response = await transport._json(
        'POST',
        'mobile/launches',
        {
          'releaseId': releaseId,
          'idempotencyKey': idempotencyKey,
          'customerReference': ?customerReference,
          'presentation': hosted ? 'hosted' : 'native',
          'redirectUrl': returnUrl?.toString(),
        },
        authenticated: false,
        publishableKey: publishableKey,
      );
      if (response['statusCode'] != 200) invalidContract();
      final data = jsonObject(response['data']);
      if (!RegExp(r'^[a-f0-9]{24}$').hasMatch(jsonString(data['sessionId'])) ||
          data['accessChannel'] != (hosted ? 'widget' : 'native')) {
        invalidContract();
      }
      jsonBool(data['testOnly']);
      DateTime expiry(String key) {
        final text = jsonString(data[key]);
        if (!RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(text)) invalidContract();
        return DateTime.tryParse(text)?.toUtc() ?? invalidContract();
      }

      final ticketExpiry = expiry('ticketExpiresAt');
      final sessionExpiry = expiry('expiresAt');
      if (ticketExpiry.isAfter(sessionExpiry)) invalidContract();
      if (!ticketExpiry.isAfter(DateTime.now())) {
        throw const LuliVerifyException(
          'grant_expired',
          'The launch expired. Start verification again.',
        );
      }
      return data;
    } finally {
      transport.dispose();
    }
  }

  static Future<LuliVerifyNativeSessionTransport> connect({
    required LuliVerifyConfig config,
    required LuliVerifyNativeGrant grant,
    http.Client? client,
  }) async {
    if (config.presentation != LuliVerifyPresentation.nativeUi) {
      throw const LuliVerifyException(
        'wrong_presentation',
        'Use the hosted launcher for hosted-web presentation.',
      );
    }
    final transport = LuliVerifyNativeSessionTransport._(
      config,
      grant.sessionId,
      client ?? http.Client(),
    );
    try {
      final ticket = grant._consume();
      final response = await transport._json(
        'POST',
        'mobile-sessions/${grant.sessionId}/exchange',
        {'ticket': ticket},
        authenticated: false,
      );
      final data = jsonObject(response['data']);
      final token = jsonString(data['sessionToken']);
      if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(token)) invalidContract();
      transport._token = token;
      transport._last = transport._snapshot(response);
      return transport;
    } catch (_) {
      transport.dispose();
      rethrow;
    }
  }

  Uri _url(String path) => config.apiBaseUrl.replace(
    path: '${config.apiBaseUrl.path.replaceFirst(RegExp(r'/$'), '')}/$path',
  );

  Future<Map<String, Object?>> _json(
    String method,
    String path,
    Map<String, Object?>? body, {
    bool authenticated = true,
    String? publishableKey,
  }) {
    return _send((abort) {
      final request = http.AbortableRequest(
        method,
        _url(path),
        abortTrigger: abort,
      )..followRedirects = false;
      request.headers['Accept'] = 'application/json';
      if (publishableKey != null) {
        request.headers['X-Publishable-Key'] = publishableKey;
      }
      if (authenticated) request.headers['X-Session-Token'] = _token ?? '';
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      return request;
    });
  }

  Future<Map<String, Object?>> _send(
    http.BaseRequest Function(Future<void>) build,
  ) async {
    if (_closed || _busy) {
      throw const LuliVerifyException(
        'transport_busy',
        'The transport is closed or another request is running.',
      );
    }
    _busy = true;
    final abort = Completer<void>();
    _aborts.add(abort);
    final timer = Timer(const Duration(seconds: 30), () {
      if (!abort.isCompleted) abort.complete();
    });
    try {
      final response = await _client.send(build(abort.future));
      if (response.statusCode != 200 && response.statusCode != 201) {
        if (!abort.isCompleted) abort.complete();
        throw LuliVerifyException(
          switch (response.statusCode) {
            401 => 'unauthorized',
            403 => 'forbidden',
            409 => 'conflict',
            429 => 'rate_limited',
            _ => 'request_failed',
          },
          'The request could not be confirmed. Refresh or start verification again.',
        );
      }
      final bytes = BytesBuilder();
      await for (final chunk in response.stream) {
        if (bytes.length + chunk.length > 4 * 1024 * 1024) {
          if (!abort.isCompleted) abort.complete();
          invalidContract();
        }
        bytes.add(chunk);
      }
      if (_closed) {
        throw const LuliVerifyException('disposed', 'The session was closed.');
      }
      return jsonObject(jsonDecode(utf8.decode(bytes.takeBytes())));
    } on LuliVerifyException {
      rethrow;
    } catch (_) {
      throw const LuliVerifyException(
        'network_error',
        'The request could not be confirmed. Refresh before continuing.',
      );
    } finally {
      timer.cancel();
      _aborts.remove(abort);
      _busy = false;
    }
  }

  LuliVerifySession _snapshot(Map<String, Object?> response) {
    final session = LuliVerifySession.fromResponse(response);
    if (session.id != sessionId || session.raw['accessChannel'] != 'native') {
      invalidContract();
    }
    _last = session;
    return session;
  }

  @override
  Future<LuliVerifySession> read() async =>
      _snapshot(await _json('GET', 'workflow-sessions/$sessionId', null));
  @override
  Future<LuliVerifySession> submit(Map<String, Object?> body) async =>
      _snapshot(
        await _json('POST', 'workflow-sessions/$sessionId/steps', body),
      );
  @override
  Future<LuliVerifySession> cancel() async =>
      _snapshot(await _json('DELETE', 'workflow-sessions/$sessionId', null));
  Future<LuliVerifySession> recoverEvidence(int revision) async => _snapshot(
    await _json('POST', 'workflow-sessions/$sessionId/evidence/recover', {
      'revision': revision,
    }),
  );
  Future<void> removeFile(String assetId) async {
    if (!RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(assetId)) {
      throw const LuliVerifyException(
        'invalid_file',
        'Invalid file reference.',
      );
    }
    await _json('DELETE', 'workflow-sessions/$sessionId/files/$assetId', null);
  }

  Future<LuliVerifySession> saveInput({
    required int revision,
    required String stepId,
    required Map<String, Object?> input,
  }) async => _snapshot(
    await _json('PATCH', 'workflow-sessions/$sessionId/input', {
      'revision': revision,
      'stepId': stepId,
      'input': input,
    }),
  );

  Future<String> upload({
    required LuliVerifyInputContract contract,
    required String slot,
    required Uint8List bytes,
    required String mimeType,
    String? documentType,
  }) async {
    final latest = _last;
    if (latest == null ||
        latest.isTerminal ||
        !latest.expiresAt.isAfter(DateTime.now()) ||
        !latest.availableStepIds.contains(contract.stepId) ||
        !sameJson(latest.contracts[contract.stepId]?.raw, contract.raw)) {
      throw const LuliVerifyException(
        'unavailable_step',
        'Refresh before uploading evidence.',
      );
    }
    final policy = contract.uploads;
    if (policy['enabled'] != true ||
        !jsonList(policy['slots']).contains(slot) ||
        !jsonList(policy['mimeTypes']).contains(mimeType) ||
        bytes.isEmpty ||
        bytes.length > (policy['maxBytes'] as int)) {
      throw const LuliVerifyException(
        'invalid_file',
        'This file does not match the server upload requirements.',
      );
    }
    final types = jsonList(policy['documentTypes']);
    if ((policy['documentTypeRequired'] == true && documentType == null) ||
        (documentType != null && !types.contains(documentType))) {
      throw const LuliVerifyException(
        'invalid_document_type',
        'Select a document type accepted by this step.',
      );
    }
    final response = await _send((abort) {
      final request = http.AbortableMultipartRequest(
        'POST',
        _url('workflow-sessions/$sessionId/files'),
        abortTrigger: abort,
      )..followRedirects = false;
      request.headers['X-Session-Token'] = _token ?? '';
      request.fields.addAll({
        'stepId': contract.stepId,
        'slot': slot,
        'documentType': ?documentType,
      });
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename:
              'evidence.${mimeType == 'application/pdf'
                  ? 'pdf'
                  : mimeType == 'image/png'
                  ? 'png'
                  : 'jpg'}',
          contentType: MediaType.parse(mimeType),
        ),
      );
      return request;
    });
    if (response['statusCode'] != 200 && response['statusCode'] != 201) {
      invalidContract();
    }
    return jsonString(jsonObject(response['data'])['id']);
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    _token = null;
    _last = null;
    for (final abort in _aborts) {
      if (!abort.isCompleted) abort.complete();
    }
    _client.close();
  }
}
