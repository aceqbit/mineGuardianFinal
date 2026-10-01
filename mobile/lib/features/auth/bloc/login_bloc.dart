import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../contracts/enums.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/auth/session_bloc.dart';
import '../../../core/models/session_user.dart';
import '../../../core/push/push_registrar.dart';
import '../data/password_rules.dart';
import '../data/phone_validator.dart';
import 'login_event.dart';
import 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc({required AuthRepository auth, required ApiClient api, required SessionBloc session, required PushRegistrar push})
      : _auth = auth,
        _api = api,
        _session = session,
        _push = push,
        super(const LoginState()) {
    on<RoleSelected>((e, emit) => emit(state.copyWith(role: e.role, clearError: true, clearMismatch: true)));
    on<MismatchSwitchRequested>((e, emit) {
      final actual = state.mismatchActualRole;
      if (actual != null) emit(state.copyWith(role: actual, clearError: true, clearMismatch: true));
    });
    on<SubmitPressed>(_onSubmit);
  }

  final AuthRepository _auth;
  final ApiClient _api;
  final SessionBloc _session;
  final PushRegistrar _push;

  Future<void> _onSubmit(SubmitPressed e, Emitter<LoginState> emit) async {
    if (state.status == LoginStatus.submitting) return;
    final phone = validatePhone(e.isoCode, e.national);
    if (!phone.isValid) {
      emit(state.copyWith(status: LoginStatus.failure, errorMessage: phone.error));
      return;
    }
    final pw = PasswordRules.evaluate(e.password);
    if (!pw.isValid) {
      emit(state.copyWith(status: LoginStatus.failure, errorMessage: pw.firstError));
      return;
    }
    emit(state.copyWith(status: LoginStatus.submitting, clearError: true, clearMismatch: true));
    try {
      await _auth.signIn(phone.e164!, e.password);
      final json = await _api.getJson('/api/auth/me', query: {'expectedRole': state.role.wire});
      final user = SessionUser.fromMe(json);
      emit(state.copyWith(status: LoginStatus.success));
      _session.add(LoggedIn(user));
      _push.register();
    } on AuthFailure catch (f) {
      emit(state.copyWith(status: LoginStatus.failure, errorMessage: f.message));
    } on ApiException catch (ex) {
      await _auth.signOut();
      switch (ex.code) {
        case 'ROLE_MISMATCH':
          final actual = (ex.details is Map ? (ex.details as Map)['actualRole'] : null) as String?;
          emit(state.copyWith(status: LoginStatus.failure, mismatchActualRole: actual == null ? null : Role.fromWire(actual)));
        case 'USER_NOT_REGISTERED':
          emit(state.copyWith(status: LoginStatus.failure, errorMessage: 'Account setup is incomplete — sign up again'));
        case 'ACCOUNT_INACTIVE':
          emit(state.copyWith(status: LoginStatus.failure, errorMessage: 'This account is inactive. Contact your mine admin'));
        case 'NETWORK':
          emit(state.copyWith(status: LoginStatus.failure, errorMessage: 'No connection — check your internet'));
        default:
          emit(state.copyWith(status: LoginStatus.failure, errorMessage: ex.message));
      }
    } catch (_) {
      await _auth.signOut();
      emit(state.copyWith(status: LoginStatus.failure, errorMessage: 'Something went wrong. Please try again'));
    }
  }
}
