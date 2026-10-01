import 'package:equatable/equatable.dart';

import '../../../contracts/enums.dart';

sealed class LoginEvent extends Equatable {
  const LoginEvent();
  @override
  List<Object?> get props => [];
}

class RoleSelected extends LoginEvent {
  const RoleSelected(this.role);
  final Role role;
  @override
  List<Object?> get props => [role];
}

class SubmitPressed extends LoginEvent {
  const SubmitPressed({required this.isoCode, required this.national, required this.password});
  final String? isoCode;
  final String national;
  final String password;
  @override
  List<Object?> get props => [isoCode, national];
}

class MismatchSwitchRequested extends LoginEvent {
  const MismatchSwitchRequested();
}
