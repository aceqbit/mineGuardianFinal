import 'package:flutter/material.dart';

import '../../../app/responsive.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/ui/mg_button.dart';
import '../data/models/quality_report.dart';
import '../data/quality_config.dart';
import '../widgets/metric_chip.dart';

/// Shows the photo with four animated metric chips. On failure only retake options appear; on pass "Submit".
class PhotoReviewView extends StatelessWidget {
  const PhotoReviewView({
    super.key,
    required this.report,
    required this.mode,
    required this.gating,
    required this.onRetake,
    required this.onChooseAnother,
    required this.onSwitchToCamera,
    required this.onSubmit,
    this.heroTag,
    this.submitLabel = 'Submit check-in',
    this.cameraAvailable = true,
  });

  final QualityReport? report;
  final GateMode mode;
  final bool gating;
  final VoidCallback onRetake;
  final VoidCallback onChooseAnother;
  final VoidCallback onSwitchToCamera;
  final VoidCallback onSubmit;
  final String? heroTag;
  final String submitLabel;
  final bool cameraAvailable;

  static const _lighting = {'DARK', 'BRIGHT', 'EXPOSURE'};
  static const _framing = {'NO_PERSON', 'FEET_CUT', 'HEAD_CUT', 'TOO_FAR', 'OFF_CENTRE'};

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final t = Theme.of(context).textTheme;
    final r = report;
    MetricState st(bool failed) => gating || r == null ? MetricState.checking : (failed ? MetricState.fail : MetricState.pass);
    final sharpFail = r?.hasFailure('BLURRY') ?? false;
    final lightFail = r?.failures.any((f) => _lighting.contains(f.code)) ?? false;
    final frameFail = r?.failures.any((f) => _framing.contains(f.code)) ?? false;
    final timeFail = r?.hasFailure('STALE') ?? false;
    final poseChecked = r?.metrics.poseChecked ?? false;

    final photo = ClipRRect(
      borderRadius: BorderRadius.circular(Radii.card),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: r == null
            ? ColoredBox(color: c.ink800)
            : Image.memory(r.uploadBytes, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, _, _) => ColoredBox(color: c.ink800, child: const Icon(Icons.broken_image, color: Colors.white54))),
      ),
    );

    final chips = Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
      MetricChip(label: 'Sharpness', state: st(sharpFail), detail: r?.metrics.blurScore.toStringAsFixed(0), delay: Duration.zero),
      MetricChip(label: 'Lighting', state: st(lightFail), delay: const Duration(milliseconds: 80)),
      if (mode == GateMode.checkin)
        MetricChip(label: 'Framing', state: gating || r == null ? MetricState.checking : (poseChecked ? st(frameFail) : MetricState.neutral), detail: poseChecked || r == null || gating ? null : 'server checks', delay: const Duration(milliseconds: 160)),
      MetricChip(label: 'Timestamp', state: st(timeFail), detail: r?.warnings.contains('NO_EXIF') == true ? 'no EXIF' : null, delay: const Duration(milliseconds: 240)),
    ]);

    final first = r?.firstFailure;
    final result = gating || r == null
        ? Text('Checking your photo…', style: t.bodyMedium)
        : first != null
            ? Container(
                padding: const EdgeInsets.all(Space.md),
                decoration: BoxDecoration(color: c.dangerBg, borderRadius: BorderRadius.circular(Radii.sm)),
                child: Row(children: [Icon(Icons.error_outline, color: c.danger), const SizedBox(width: Space.sm), Expanded(child: Text(first.message, style: t.bodyMedium?.copyWith(color: c.danger)))]),
              )
            : Container(
                padding: const EdgeInsets.all(Space.md),
                decoration: BoxDecoration(color: c.successBg, borderRadius: BorderRadius.circular(Radii.sm)),
                child: Row(children: [Icon(Icons.check_circle, color: c.success), const SizedBox(width: Space.sm), Expanded(child: Text('Photo looks good', style: t.bodyMedium?.copyWith(color: c.success)))]),
              );

    final actions = <Widget>[
      if (!gating && r != null && r.pass) MgButton(label: submitLabel, expand: true, icon: Icons.cloud_upload, onPressed: onSubmit),
      if (!gating && r != null && !r.pass) ...[
        MgButton(label: r.source == 'camera' ? 'Retake' : 'Choose another photo', expand: true, icon: r.source == 'camera' ? Icons.refresh : Icons.photo_library, onPressed: r.source == 'camera' ? onRetake : onChooseAnother),
        if (r.source == 'gallery' && cameraAvailable) MgButton(label: 'Switch to camera', expand: true, kind: MgButtonKind.secondary, icon: Icons.photo_camera, onPressed: onSwitchToCamera),
      ],
      if (!gating && r != null && r.pass) MgButton(label: r.source == 'camera' ? 'Retake' : 'Choose another photo', expand: true, kind: MgButtonKind.ghost, onPressed: r.source == 'camera' ? onRetake : onChooseAnother),
    ];

    final detail = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      chips,
      const SizedBox(height: Space.lg),
      result,
      const SizedBox(height: Space.x2),
      for (final a in actions) Padding(padding: const EdgeInsets.only(bottom: Space.md), child: a),
    ]);

    final img = heroTag == null ? photo : Hero(tag: heroTag!, child: photo);
    if (context.isCompact) {
      return ListView(padding: const EdgeInsets.all(Space.lg), children: [ConstrainedBox(constraints: const BoxConstraints(maxHeight: 420), child: Center(child: img)), const SizedBox(height: Space.lg), detail]);
    }
    return ContentWidth(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.lg),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 5, child: img),
          const SizedBox(width: Space.x2),
          Expanded(flex: 6, child: SingleChildScrollView(child: detail)),
        ]),
      ),
    );
  }
}
