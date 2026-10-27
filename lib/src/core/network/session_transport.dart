import '../../features/session/workflow_session.dart';

/// Bound to one session. Authentication stays inside a future audited adapter.
/// No browser Origin spoofing and no merchant secrets in implementations.
abstract interface class LuliVerifySessionTransport {
  Future<LuliVerifySession> read();
  Future<LuliVerifySession> submit(Map<String, Object?> body);
  Future<LuliVerifySession> cancel();
  void dispose();
}
