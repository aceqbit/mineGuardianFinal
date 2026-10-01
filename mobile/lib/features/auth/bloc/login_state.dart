import 'package:equatable/equatable.dart';

import '../../../contracts/enums.dart';

enum LoginStatus { idle, submitting, failure, success }

/// Form text lives in widget controllers, never here.
class LoginState extends Equatable {
  const LoginState({this.role = Role.miner, this.status = LoginStatus.idle, this.errorMessage, this.mismatchActualRole});
  final Role role;
  final LoginStatus status;
  final String? errorMessage;
  final Role? mismatchActualRole;

  LoginState copyWith({Role? role, LoginStatus? status, String? errorMessage, Role? mismatchActualRole, bool clearError = false, bool clearMismatch = false}) => LoginState(
        role: role ?? this.role,
        status: status ?? this.status,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        mismatchActualRole: clearMismatch ? null : (mismatchActualRole ?? this.mismatchActualRole),
      );

  @override
  List<Object?> get props => [role, status, errorMessage, mismatchActualRole];
}
