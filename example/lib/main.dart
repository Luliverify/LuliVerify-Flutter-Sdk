import 'package:flutter/material.dart';
import 'package:luliverify_flutter/luliverify_flutter.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'LuliVerify',
    theme: LuliVerifyDesign.theme(),
    home: const LaunchPage(),
  );
}

/// Merchant example: the SDK owns the route and session after launch().
class LaunchPage extends StatefulWidget {
  const LaunchPage({super.key});
  @override
  State<LaunchPage> createState() => _LaunchPageState();
}

class _LaunchPageState extends State<LaunchPage> {
  final _key = TextEditingController(
    text: const String.fromEnvironment('PUBLISHABLE_KEY'),
  );
  final _release = TextEditingController(
    text: const String.fromEnvironment('RELEASE_ID'),
  );
  final _return = TextEditingController(
    text: const String.fromEnvironment('RETURN_URL'),
  );
  bool _busy = false, _hosted = false;
  String? _message;
  @override
  void dispose() {
    _key.dispose();
    _release.dispose();
    _return.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 40),
              const Text(
                'LuliVerify',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text(
                'SDK integration example',
                style: TextStyle(fontSize: 16, color: Color(0xff5d6375)),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _key,
                enabled: !_busy,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Publishable key'),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _release,
                enabled: !_busy,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Published workflow ID',
                ),
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Use hosted browser flow'),
                value: _hosted,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _hosted = value),
              ),
              if (_hosted) ...[
                TextField(
                  controller: _return,
                  enabled: !_busy,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Registered HTTPS app return URL',
                  ),
                ),
                const SizedBox(height: 20),
              ],
              const SizedBox(height: 12),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _busy ? null : _launch,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(_busy ? 'Opening...' : 'Start verification'),
                ),
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Semantics(liveRegion: true, child: Text(_message!)),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  Future<void> _launch() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await LuliVerify.launch(
        context,
        publishableKey: _key.text.trim(),
        releaseId: _release.text.trim(),
        mode: _hosted
            ? LuliVerifyPresentation.hostedWeb
            : LuliVerifyPresentation.nativeUi,
        apiBaseUrl: Uri.parse(
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'https://luli-api.luliverify.io',
          ),
        ),
        returnUrl: _hosted ? Uri.parse(_return.text.trim()) : null,
      );
      if (mounted) {
        setState(
          () => _message =
              'Session: ${result.status.name}. This callback is advisory.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Unable to open verification. Check your configuration.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
