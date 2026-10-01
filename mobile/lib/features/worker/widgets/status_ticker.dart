import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/responsive.dart';
import '../../../app/theme/motion.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/ui/mg_card.dart';
import '../bloc/checkin_flow_state.dart';

enum NodeState { idle, active, done, failed }

const tickerLabels = ['Checking', 'Uploading', 'Synced', 'AI analysing', 'Done'];

String tickerHeadline(CheckinFlowState s) {
  if (s.phase == FlowPhase.failed) return 'Something went wrong';
  if (s.phase == FlowPhase.queuedOffline) return 'Saved offline';
  switch (s.stage) {
    case TickerStage.checking:
      return 'Checking your photo';
    case TickerStage.uploading:
      return 'Uploading';
    case TickerStage.synced:
      return 'Server check passed';
    case TickerStage.aiAnalyzing:
      return s.aiSlow ? 'AI is taking longer — your supervisor will still review it' : 'AI is analysing';
    case TickerStage.done:
      return 'All done';
  }
}

/// Big animated stage tracker. Horizontal on medium/expanded, vertical on compact. Motion stops with reduced motion.
class StatusTicker extends StatefulWidget {
  const StatusTicker({super.key, required this.state, required this.startedAt});
  final CheckinFlowState state;
  final DateTime startedAt;

  @override
  State<StatusTicker> createState() => _StatusTickerState();
}

class _StatusTickerState extends State<StatusTicker> {
  Timer? _tick;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (widget.state.phase == FlowPhase.running) setState(() => _elapsed = DateTime.now().difference(widget.startedAt));
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  NodeState _nodeState(int i) {
    final s = widget.state;
    final cur = s.stage.index;
    if (s.phase == FlowPhase.failed && s.failure != null) {
      final f = s.failure!.stage.index;
      if (i < f) return NodeState.done;
      if (i == f) return NodeState.failed;
      return NodeState.idle;
    }
    if (s.phase == FlowPhase.done) return NodeState.done;
    if (s.phase == FlowPhase.queuedOffline) return i <= 0 ? NodeState.done : (i == 1 ? NodeState.active : NodeState.idle);
    if (i < cur) return NodeState.done;
    if (i == cur) return NodeState.active;
    return NodeState.idle;
  }

  String _elapsedText() {
    final m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final t = Theme.of(context).textTheme;
    final s = widget.state;
    final horizontal = !context.isCompact;
    final nodes = [for (var i = 0; i < 5; i++) _Node(label: tickerLabels[i], state: _nodeState(i))];

    final Widget track = horizontal
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < 5; i++) ...[
              Expanded(child: nodes[i]),
              if (i < 4) _HConnector(filled: _nodeState(i) == NodeState.done && _nodeState(i + 1) != NodeState.idle || _nodeState(i) == NodeState.done && _nodeState(i + 1) == NodeState.done),
            ],
          ])
        : Column(children: [
            for (var i = 0; i < 5; i++) ...[
              nodes[i],
              if (i < 4) _VConnector(filled: _nodeState(i) == NodeState.done),
            ],
          ]);

    final failed = s.phase == FlowPhase.failed;
    final headline = Text(
      failed ? (s.failure?.message ?? tickerHeadline(s)) : tickerHeadline(s),
      key: ValueKey('${s.phase}-${s.stage}-${s.aiSlow}'),
      style: t.headlineSmall?.copyWith(color: failed ? c.danger : null),
    );
    final detail = s.detail.isEmpty ? '' : s.detail;

    return Semantics(
      liveRegion: true,
      label: '${tickerHeadline(s)}. $detail',
      child: MgCard(
        padding: const EdgeInsets.all(Space.x2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          track,
          const SizedBox(height: Space.x2),
          AnimatedSwitcher(duration: Motion.of(context, Motion.base), child: headline),
          const SizedBox(height: Space.xs),
          if (detail.isNotEmpty) Text(detail, style: t.bodyMedium?.copyWith(color: c.muted)),
          const SizedBox(height: Space.sm),
          if (s.phase == FlowPhase.running)
            Text(_elapsedText(), style: t.labelLarge?.copyWith(color: c.muted, fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      ),
    );
  }
}

class _HConnector extends StatelessWidget {
  const _HConnector({required this.filled});
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return SizedBox(
      width: 24,
      height: 40,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(height: 3, color: c.border, alignment: Alignment.centerLeft, child: AnimatedContainer(duration: Motion.of(context, Motion.slow), curve: Motion.easeOut, height: 3, width: filled ? 24 : 0, color: c.success)),
      ),
    );
  }
}

class _VConnector extends StatelessWidget {
  const _VConnector({required this.filled});
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Container(
      width: 3,
      height: 20,
      color: c.border,
      alignment: Alignment.topCenter,
      child: AnimatedContainer(duration: Motion.of(context, Motion.slow), curve: Motion.easeOut, width: 3, height: filled ? 20 : 0, color: c.success),
    );
  }
}

class _Node extends StatefulWidget {
  const _Node({required this.label, required this.state});
  final String label;
  final NodeState state;

  @override
  State<_Node> createState() => _NodeState();
}

class _NodeState extends State<_Node> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _Node old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.state == NodeState.active && !Motion.reduce(context)) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final t = Theme.of(context).textTheme;
    final st = widget.state;
    final reduce = Motion.reduce(context);
    final color = switch (st) { NodeState.idle => c.slate300, NodeState.active => c.amber500, NodeState.done => c.success, NodeState.failed => c.danger };
    Widget dot = AnimatedBuilder(
      animation: _spin,
      builder: (context, _) {
        final pulse = st == NodeState.active && !reduce ? 1 + 0.06 * math.sin(_spin.value * 2 * math.pi) : 1.0;
        return Transform.scale(scale: pulse, child: SizedBox(width: 40, height: 40, child: CustomPaint(painter: _NodePainter(state: st, color: color, spin: _spin.value, bg: c.surface), child: const SizedBox.expand())));
      },
    );
    if (st == NodeState.done && !reduce) {
      dot = TweenAnimationBuilder<double>(
        key: const ValueKey('done'),
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: Motion.slow,
        builder: (context, v, child) => Transform.scale(scale: 1 + 0.15 * math.sin(v * math.pi), child: child),
        child: dot,
      );
    }
    if (st == NodeState.failed && !reduce) {
      dot = TweenAnimationBuilder<double>(
        key: const ValueKey('fail'),
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 400),
        builder: (context, v, child) => Transform.translate(offset: Offset(math.sin(v * 3 * 2 * math.pi) * 6 * (1 - v), 0), child: child),
        child: dot,
      );
    }
    final label = Text(widget.label, textAlign: TextAlign.center, style: t.labelMedium?.copyWith(color: st == NodeState.idle ? c.muted : c.text));
    return Semantics(
      label: '${widget.label}: ${st.name}',
      excludeSemantics: true,
      child: MediaQuery.sizeOf(context).width < 600
          ? Row(children: [dot, const SizedBox(width: Space.md), Expanded(child: Align(alignment: Alignment.centerLeft, child: label))])
          : Column(children: [dot, const SizedBox(height: Space.xs), label]),
    );
  }
}

class _NodePainter extends CustomPainter {
  _NodePainter({required this.state, required this.color, required this.spin, required this.bg});
  final NodeState state;
  final Color color;
  final double spin;
  final Color bg;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 2;
    switch (state) {
      case NodeState.idle:
        canvas.drawCircle(c, r, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 3);
      case NodeState.active:
        canvas.drawCircle(c, r, Paint()..color = color.withValues(alpha: 0.25)..style = PaintingStyle.stroke..strokeWidth = 3);
        canvas.drawArc(Rect.fromCircle(center: c, radius: r), spin * 2 * math.pi, math.pi * 0.7, false, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round);
      case NodeState.done:
        canvas.drawCircle(c, r, Paint()..color = color);
        final p = Path()..moveTo(c.dx - 8, c.dy + 1)..lineTo(c.dx - 2, c.dy + 7)..lineTo(c.dx + 9, c.dy - 6);
        canvas.drawPath(p, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3.5..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
      case NodeState.failed:
        canvas.drawCircle(c, r, Paint()..color = color);
        final x = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3.5..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(c.dx - 7, c.dy - 7), Offset(c.dx + 7, c.dy + 7), x);
        canvas.drawLine(Offset(c.dx + 7, c.dy - 7), Offset(c.dx - 7, c.dy + 7), x);
    }
  }

  @override
  bool shouldRepaint(covariant _NodePainter old) => old.state != state || old.spin != spin || old.color != color;
}
