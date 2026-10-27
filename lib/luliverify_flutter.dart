/// Native and hosted session integration. The backend owns verification outcomes.
library;

export 'src/luliverify.dart';
export 'src/presentation/design/luli_components.dart' show LuliVerifyDesign;

export 'src/core/config/luliverify_config.dart';
export 'src/core/errors/luliverify_exception.dart';
export 'src/core/contracts/input_contract.dart';
export 'src/core/network/session_transport.dart';
export 'src/core/network/native_session_transport.dart';
export 'src/presentation/native/contract_form.dart';
export 'src/presentation/native/session_screen.dart';
export 'src/platform/evidence_picker.dart';
export 'src/presentation/hosted/hosted_launch.dart';
export 'src/features/session/workflow_session.dart';
export 'src/features/session/session_controller.dart';
