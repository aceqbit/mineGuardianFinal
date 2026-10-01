import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/models/quality_report.dart';
import '../data/quality_config.dart';
import '../data/quality_gate.dart';
import 'capture_event.dart';
import 'capture_state.dart';

class CaptureBloc extends Bloc<CaptureEvent, CaptureState> {
  CaptureBloc({QualityGate? gate, this.mode = GateMode.checkin})
      : _gate = gate ?? QualityGate(),
        super(const CaptureState()) {
    on<CameraOpened>((e, emit) => emit(state.copyWith(phase: CapturePhase.camera)));
    on<CameraClosed>((e, emit) => emit(state.copyWith(phase: CapturePhase.menu)));
    on<PhotoSelected>(_onPhoto);
    on<RetakeRequested>((e, emit) => emit(CaptureState(phase: e.toCamera ? CapturePhase.camera : CapturePhase.menu, attempt: state.attempt + 1)));
  }

  final QualityGate _gate;
  final GateMode mode;

  Future<void> _onPhoto(PhotoSelected e, Emitter<CaptureState> emit) async {
    emit(state.copyWith(phase: CapturePhase.gating, source: e.source, clearReport: true));
    QualityReport report;
    try {
      report = await _gate.evaluate(bytes: e.bytes, source: e.source, mode: mode, shutterAt: e.shutterAt);
    } catch (_) {
      report = QualityReport(
        failures: const [QualityFailure('UNREADABLE', 'This photo could not be checked — try another')],
        warnings: const [],
        metrics: const QualityMetrics(),
        capturedAt: e.shutterAt,
        exifTakenAt: null,
        source: e.source,
        sha256: '',
        uploadBytes: e.bytes,
        gateMs: 0,
      );
    }
    emit(state.copyWith(phase: CapturePhase.review, report: report));
  }

  @override
  Future<void> close() async {
    await _gate.dispose();
    return super.close();
  }
}
