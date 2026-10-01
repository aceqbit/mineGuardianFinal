import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mine_guardian/app/theme/tokens.dart';
import 'package:mine_guardian/features/worker/bloc/checkin_flow_state.dart';
import 'package:mine_guardian/features/worker/widgets/status_ticker.dart';

void main() {
  final states = <String, CheckinFlowState>{
    'checking': const CheckinFlowState(detail: 'Sharpness 142 ✓ · Lighting ✓ · Full body ✓'),
    'uploading': const CheckinFlowState(stage: TickerStage.uploading, progress: .64, detail: 'Uploading 64%'),
    'synced': const CheckinFlowState(stage: TickerStage.synced, detail: 'Server check passed'),
    'ai': const CheckinFlowState(stage: TickerStage.aiAnalyzing, detail: 'AI checking your PPE…'),
    'slow': const CheckinFlowState(stage: TickerStage.aiAnalyzing, aiSlow: true),
    'done': const CheckinFlowState(phase: FlowPhase.done, stage: TickerStage.done, detail: 'AI done: awaiting supervisor'),
    'failed': const CheckinFlowState(phase: FlowPhase.failed, failure: FlowFailure(stage: TickerStage.uploading, message: 'No connection', action: FailAction.retry)),
  };

  for (final size in const [Size(360, 780), Size(768, 1024), Size(1280, 800)]) {
    testWidgets('ticker renders every stage at ${size.width.toInt()}px without overflow', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final errs = <String>[];
      final prev = FlutterError.onError;
      FlutterError.onError = (d) => errs.add(d.toDiagnosticsNode().toStringDeep());
      for (final e in states.entries) {
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: const [MgColors.light]),
          home: Scaffold(body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16), child: StatusTicker(state: e.value, startedAt: DateTime.now())))),
        ));
        await tester.pump(const Duration(milliseconds: 500));
      }
      FlutterError.onError = prev;
      expect(errs, isEmpty, reason: errs.join('\n---\n'));
      expect(find.text('Failed'), findsNothing);
    });
  }
}
