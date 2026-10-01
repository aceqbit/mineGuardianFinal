import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/signup_repository.dart';
import 'signup_event.dart';
import 'signup_state.dart';

class SignupBloc extends Bloc<SignupEvent, SignupState> {
  SignupBloc({required SignupRepository repo}) : _repo = repo, super(const SignupState()) {
    on<SignupStarted>(_onStarted);
    on<SignupFieldsChanged>(_onFields);
    on<SignupStepChanged>((e, emit) => emit(state.copyWith(step: e.step.clamp(0, 2), clearError: true)));
    on<SignupSubmitted>(_onSubmit);
  }

  final SignupRepository _repo;

  Future<void> _onStarted(SignupStarted e, Emitter<SignupState> emit) async {
    emit(state.copyWith(status: SignupStatus.loadingZones));
    try {
      final zones = await _repo.zones();
      emit(state.copyWith(status: SignupStatus.idle, zones: zones));
    } catch (_) {
      emit(state.copyWith(status: SignupStatus.zonesFailed));
    }
  }

  void _onFields(SignupFieldsChanged e, Emitter<SignupState> emit) {
    final mineChanged = e.mineName != null && e.mineName != state.mineName;
    emit(state.copyWith(
      role: e.role,
      mineName: e.mineName,
      clearZone: mineChanged,
      zoneId: mineChanged ? null : e.zoneId,
      shift: e.shift,
      designation: e.designation,
      experienceYears: e.experienceYears,
      dateOfJoining: e.dateOfJoining,
      dob: e.dob,
      bloodGroup: e.bloodGroup,
      relation: e.relation,
      consent: e.consent,
    ));
  }

  Future<void> _onSubmit(SignupSubmitted e, Emitter<SignupState> emit) async {
    if (state.status == SignupStatus.submitting) return;
    emit(state.copyWith(status: SignupStatus.submitting, clearError: true, progressLabel: 'Creating account…', alreadyRegistered: false));
    try {
      final user = await _repo.register(e.data, onStage: (s) => emit(state.copyWith(progressLabel: s)));
      emit(state.copyWith(status: SignupStatus.success, user: user));
    } on SignupFailure catch (f) {
      emit(state.copyWith(status: SignupStatus.failure, errorMessage: f.message, errorStep: f.step, step: f.step, alreadyRegistered: f.alreadyRegistered));
    } catch (_) {
      emit(state.copyWith(status: SignupStatus.failure, errorMessage: 'Something went wrong. Please try again', errorStep: 2));
    }
  }
}
