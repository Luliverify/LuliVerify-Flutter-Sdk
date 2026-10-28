import '../../features/session/workflow_session.dart';

/// Session-bound I/O boundary used by the observable controller.
///
/// Implementations own authentication and resources. Never spoof browser Origin
/// or embed private merchant credentials. NativeSessionTransport is the built-in
/// adapter; custom adapters must preserve session/revision and error boundaries.
abstract interface class LuliVerifySessionTransport {
  /// Fetches the current session snapshot without advancing its workflow.
  Future<LuliVerifySession> read();

  /// Submits a revision-aware step envelope and returns the accepted snapshot.
  ///
  /// Do not automatically retry ambiguous mutations.
  Future<LuliVerifySession> submit(Map<String, Object?> body);

  /// Requests remote cancellation and returns the resulting backend snapshot.
  Future<LuliVerifySession> cancel();

  /// Releases local resources and invalidates pending work.
  ///
  /// Disposal itself must not be presented as confirmed remote cancellation.
  void dispose();
}
