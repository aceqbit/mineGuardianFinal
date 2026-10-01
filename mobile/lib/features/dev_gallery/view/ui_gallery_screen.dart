import 'package:flutter/material.dart';

import '../../../app/app_images.dart';
import '../../../app/responsive.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/ui/animated_counter.dart';
import '../../../app/ui/empty_state.dart';
import '../../../app/ui/media_tile.dart';
import '../../../app/ui/mg_button.dart';
import '../../../app/ui/mg_card.dart';
import '../../../app/ui/mg_segmented.dart';
import '../../../app/ui/mg_text_field.dart';
import '../../../app/ui/pulse_dot.dart';
import '../../../app/ui/section_header.dart';
import '../../../app/ui/skeleton.dart';
import '../../../app/ui/stat_card.dart';
import '../../../app/ui/status_chip.dart';
import '../../../app/ui/toast.dart';

/// Debug-only UI gallery at /dev/ui.
class UiGalleryScreen extends StatefulWidget {
  const UiGalleryScreen({super.key, this.onToggleTheme});
  final VoidCallback? onToggleTheme;

  @override
  State<UiGalleryScreen> createState() => _UiGalleryScreenState();
}

class _UiGalleryScreenState extends State<UiGalleryScreen> {
  final _ctrl = TextEditingController();
  String _seg = 'a';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('UI gallery'), actions: [
        IconButton(icon: const Icon(Icons.brightness_6), tooltip: 'Toggle theme', onPressed: widget.onToggleTheme),
      ]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: Space.lg),
        child: ContentWidth(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionHeader(title: 'Buttons', number: 1),
            Wrap(spacing: Space.md, runSpacing: Space.md, children: [
              MgButton(label: 'Primary', onPressed: () => Toast.show(context, 'Saved', kind: ToastKind.success)),
              MgButton(label: 'Secondary', kind: MgButtonKind.secondary, onPressed: () {}),
              MgButton(label: 'Danger', kind: MgButtonKind.danger, icon: Icons.warning, onPressed: () {}),
              MgButton(label: 'Ghost', kind: MgButtonKind.ghost, onPressed: () {}),
              const MgButton(label: 'Disabled', onPressed: null),
              MgButton(label: 'Loading', loading: true, onPressed: () {}),
            ]),
            const SizedBox(height: Space.x2),
            const SectionHeader(title: 'Stats', number: 2),
            AdaptiveGrid(aspectRatio: 1.6, children: const [
              StatCard(label: 'Safety score', value: 742, icon: Icons.shield),
              StatCard(label: 'Streak', value: 6, icon: Icons.local_fire_department, suffix: ' d'),
              StatCard(label: 'XP', value: 1200, icon: Icons.bolt),
              StatCard(label: 'Rank', value: null, icon: Icons.emoji_events, prefix: '#'),
            ]),
            const SizedBox(height: Space.x2),
            const SectionHeader(title: 'Chips', number: 3),
            Wrap(spacing: Space.sm, runSpacing: Space.sm, children: const [
              StatusChip(label: 'Neutral'),
              StatusChip(label: 'Compliant', tone: ChipTone.success, icon: Icons.check),
              StatusChip(label: 'Warning', tone: ChipTone.warning),
              StatusChip(label: 'Non-compliant', tone: ChipTone.danger),
              StatusChip(label: 'Live', tone: ChipTone.info),
              StatusChip(label: 'CRISIS', tone: ChipTone.crisis),
            ]),
            const SizedBox(height: Space.x2),
            const SectionHeader(title: 'Media tiles', number: 4),
            AdaptiveGrid(children: [
              MediaTile(imageUrl: AppImages.capture, icon: Icons.photo_camera, title: 'Capture Shift Photo', subtitle: 'Not submitted today'),
              MediaTile(imageUrl: AppImages.hazard, icon: Icons.warning_amber, title: 'Report Hazard'),
              MediaTile(imageUrl: AppImages.leaderboard, icon: Icons.leaderboard, title: 'Leaderboard'),
              MediaTile(imageUrl: AppImages.rewards, icon: Icons.emoji_events, title: 'Rewards'),
            ]),
            const SizedBox(height: Space.x2),
            const SectionHeader(title: 'Inputs', number: 5),
            MgTextField(controller: _ctrl, label: 'Never autofills', hint: 'Type here'),
            const SizedBox(height: Space.lg),
            MgSegmented<String>(
              value: _seg,
              onChanged: (v) => setState(() => _seg = v),
              segments: const [
                MgSegment(value: 'a', label: 'Miner', icon: Icons.engineering),
                MgSegment(value: 'b', label: 'Supervisor', icon: Icons.badge),
                MgSegment(value: 'c', label: 'Admin', icon: Icons.admin_panel_settings),
              ],
            ),
            const SizedBox(height: Space.x2),
            const SectionHeader(title: 'Misc', number: 6),
            Row(children: [
              PulseDot(color: c.success),
              const SizedBox(width: Space.sm),
              const Text('Live'),
              const Spacer(),
              const AnimatedCounter(value: 4217),
            ]),
            const SizedBox(height: Space.lg),
            const SkeletonList(count: 2),
            MgCard(child: const SizedBox(height: 120, child: EmptyState(icon: Icons.inbox, title: 'Nothing here yet', message: 'New items appear live'))),
          ]),
        ),
      ),
    );
  }
}
