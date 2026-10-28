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

/// Memory-only, single-use authorization grant for a native session.
///
/// Contains a private launch ticket, not a publishable or merchant key. Never log,
/// persist, reuse or send it to the hosted widget. Use [fromJson] on grant data.
final class LuliVerifyNativeGrant {
  /// Parses native grant data, not the outer API response envelope.
  ///
  /// Requires a 24-character hexadecimal session ID, a 43-character opaque ticket,
  /// native accessChannel and a timezone-qualified ticketExpiresAt. Malformed data
  /// throws LuliVerifyException. Expiry/consumption are checked at exchange time.
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

  /// Session this grant authorizes; an ID alone cannot restore access.
  late final String sessionId;

  /// UTC deadline for consuming the grant; distinct from session expiry.
  late final DateTime ticketExpiresAt;
  late String _ticket;
  bool _consumed = false;

  /// Returns and clears the ticket once, even if a later exchange is ambiguous.
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

/// Native HTTP adapter owning one client and one session’s in-memory token.
///
/// Use [createLaunch] then [connect] for advanced integration. Session credentials
/// never enter public snapshots. Requests omit browser Origin, reject redirects
/// and are not retried automatically. Operations must not overlap.
///
/// A controller that receives this transport owns its disposal. Standalone users
/// must call [dispose] themselves; disposal does not cancel the remote session.
final class LuliVerifyNativeSessionTransport
    implements LuliVerifySessionTransport {
  LuliVerifyNativeSessionTransport._(this.config, this.sessionId, this._client);

  /// Validated API base and presentation used by this transport.
  final LuliVerifyConfig config;

  /// Native session identifier used for every authenticated session endpoint.
  final String sessionId;
  final http.Client _client;
  String? _token;
  bool _closed = false;
  bool _busy = false;
  final Set<Completer<void>> _aborts = {};
  LuliVerifySession? _last;

  /// Latest successfully adopted transport snapshot, initially from exchange.
  ///
  /// Despite the name, reads/mutations update this value. A separate controller
  /// must refresh to adopt transport-side changes into its own revision state.
  LuliVerifySession get initialSession => _last!;

  /// Creates a mobile launch using an issued publishable key and allowed release.
  ///
  /// [config] selects native or hosted presentation. [publishableKey] must be an
  /// issued lv_pk_ value; [releaseId] is a published 24-character lowercase hex ID.
  /// [idempotencyKey] is an 8–100 character request identifier. Optional
  /// [customerReference] is correlation only, 1–150 characters when present.
  ///
  /// Hosted launch requires a registered HTTPS [returnUrl]; native launch must
  /// omit it. The returned data contains a sensitive one-use native ticket or
  /// hosted launch URL. Never log or persist that data.
  ///
  /// This method owns and closes [client], including on failure; when omitted it
  /// creates its own. Return a fresh client per call. Invalid arguments throw
  /// [ArgumentError]; backend, expiry and network failures throw LuliVerifyException.
  /// Do not automatically retry an ambiguous creation or consume a ticket twice.
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

  /// Exchanges [grant] once and returns an authenticated native transport.
  ///
  /// [config] must select native UI. Owns [client] on both success and failure;
  /// uses a new client if omitted. The grant is consumed before the network request,
  /// so an uncertain exchange cannot be retried with the same grant.
  ///
  /// [initialSession] exposes the validated exchange snapshot without its token.
  /// Throws LuliVerifyException on invalid/expired credentials, wrong presentation,
  /// contract or network failures. Dispose the returned transport when no controller
  /// owns it. Obtain a new authorized grant after an ambiguous exchange.
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

  /// Appends a validated endpoint path to the configured HTTPS API prefix.
  Uri _url(String path) => config.apiBaseUrl.replace(
    path: '${config.apiBaseUrl.path.replaceFirst(RegExp(r'/$'), '')}/$path',
  );

  /// Builds JSON requests with only publishable-key or scoped session authentication.
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

  /// Serializes a bounded, abortable request and sanitizes network failures.
  ///
  /// Uses a 30-second abort trigger and a 4 MiB response-body limit; never retries.
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

  /// Validates native access/session ownership before replacing the latest snapshot.
  LuliVerifySession _snapshot(Map<String, Object?> response) {
    final session = LuliVerifySession.fromResponse(response);
    if (session.id != sessionId || session.raw['accessChannel'] != 'native') {
      invalidContract();
    }
    _last = session;
    return session;
  }

  @override
  /// Fetches the current native session and updates [initialSession].
  ///
  /// Throws LuliVerifyException on I/O, access, contract or overlap failure.
  Future<LuliVerifySession> read() async =>
      _snapshot(await _json('GET', 'workflow-sessions/$sessionId', null));
  @override
  /// Submits a backend step envelope and updates the latest snapshot.
  ///
  /// Use the controller to construct revision/idempotency/consent fields safely.
  /// Throws LuliVerifyException on failure; do not blindly replay an uncertain call.
  Future<LuliVerifySession> submit(Map<String, Object?> body) async =>
      _snapshot(
        await _json('POST', 'workflow-sessions/$sessionId/steps', body),
      );
  @override
  /// Requests remote session cancellation and adopts its backend snapshot.
  ///
  /// Only the returned status confirms cancellation. Local disposal is separate.
  Future<LuliVerifySession> cancel() async =>
      _snapshot(await _json('DELETE', 'workflow-sessions/$sessionId', null));

  /// Requests backend-approved recovery at [revision] for expired/missing evidence.
  ///
  /// Follow the current action flag and refresh the controller after success. The
  /// backend resolves which earlier capture must be repeated; do not choose arbitrary
  /// source asset IDs. Throws LuliVerifyException on rejected or uncertain recovery.
  Future<LuliVerifySession> recoverEvidence(int revision) async => _snapshot(
    await _json('POST', 'workflow-sessions/$sessionId/evidence/recover', {
      'revision': revision,
    }),
  );

  /// Removes one session-owned uploaded file identified by [assetId].
  ///
  /// The ID must be 24 hexadecimal characters. Refresh the controller after success;
  /// this operation does not itself adopt a new controller snapshot. Throws
  /// LuliVerifyException for an invalid ID, access, conflict or network failure.
  Future<void> removeFile(String assetId) async {
    if (!RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(assetId)) {
      throw const LuliVerifyException(
        'invalid_file',
        'Invalid file reference.',
      );
    }
    await _json('DELETE', 'workflow-sessions/$sessionId/files/$assetId', null);
  }

  /// Saves partial scalar answers for [stepId] at the supplied [revision].
  ///
  /// [input] uses backend field keys. Autosave does not complete the step. Serialise
  /// with other session operations, then refresh the controller before submitting.
  /// Throws LuliVerifyException for backend, contract or network failures.
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

  /// Uploads file bytes for the current backend [contract] and returns an asset ID.
  ///
  /// [slot] and optional [documentType] are backend values, not display labels.
  /// [mimeType], [bytes] size and document type must satisfy the current contract.
  /// The transport rejects stale/unavailable contracts before upload; the backend
  /// remains authoritative about file/role eligibility and ownership.
  ///
  /// [onProgress] reports multipart request-body bytes sent/total, including overhead.
  /// It is not server acceptance: wait for this Future to succeed. The caller owns
  /// [bytes] and must not clear/mutate them until the upload finishes.
  ///
  /// Serialise with controller mutations and refresh the controller after success.
  /// Throws LuliVerifyException on policy, access, conflict, network or contract
  /// failure. Do not automatically retry an ambiguous upload.
  Future<String> upload({
    required LuliVerifyInputContract contract,
    required String slot,
    required Uint8List bytes,
    required String mimeType,
    String? documentType,
    void Function(int sent, int total)? onProgress,
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
      final request = _ProgressMultipartRequest(
        'POST',
        _url('workflow-sessions/$sessionId/files'),
        abortTrigger: abort,
        onProgress: onProgress,
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
  /// Invalidates token/snapshots, aborts pending requests and closes the owned client.
  ///
  /// Safe to call repeatedly; does not send remote cancellation.
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

/// Abortable multipart request that observes streamed request-body byte counts.
class _ProgressMultipartRequest extends http.MultipartRequest
    with http.Abortable {
  _ProgressMultipartRequest(
    super.method,
    super.url, {
    this.abortTrigger,
    this.onProgress,
  });
  @override
  final Future<void>? abortTrigger;
  final void Function(int sent, int total)? onProgress;
  @override
  /// Wraps the one-use finalized multipart stream without changing its contents.
  http.ByteStream finalize() {
    final stream = super.finalize();
    final total = contentLength;
    var sent = 0;
    return http.ByteStream(
      stream.map((chunk) {
        sent += chunk.length;
        onProgress?.call(sent, total);
        return chunk;
      }),
    );
  }
}
