import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../contracts/enums.dart';
import '../../../core/models/mine_layout.dart';
import '../data/crisis_models.dart';

/// Maps layout metres to canvas pixels; shared by painting and tap hit-testing.
class CrisisProjection {
  CrisisProjection(this.layout, this.size) {
    var minX = double.infinity, maxX = -double.infinity, minY = double.infinity, maxY = -double.infinity;
    void add(GeoPoint p) {
      final l = layout.toLocal(p);
      minX = math.min(minX, l.x);
      maxX = math.max(maxX, l.x);
      minY = math.min(minY, l.y);
      maxY = math.max(maxY, l.y);
    }

    for (final z in layout.zones) {
      z.ring.forEach(add);
    }
    for (final t in layout.tunnels) {
      t.coords.forEach(add);
    }
    final w = math.max(1.0, maxX - minX), h = math.max(1.0, maxY - minY);
    scale = math.max(0.01, math.min((size.width - 2 * _pad) / w, (size.height - 2 * _pad) / h));
    _ox = (size.width - w * scale) / 2 - minX * scale;
    _oy = (size.height - h * scale) / 2 - minY * scale;
  }

  static const double _pad = 24;
  final MineLayoutData layout;
  final Size size;
  late final double scale;
  late final double _ox, _oy;

  Offset px(GeoPoint p) {
    final l = layout.toLocal(p);
    return Offset(_ox + l.x * scale, size.height - (_oy + l.y * scale));
  }

  /// Distance in px from `o` to the segment a-b.
  static double distToSegment(Offset o, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    final t = len2 == 0 ? 0.0 : (((o - a).dx * ab.dx + (o - a).dy * ab.dy) / len2).clamp(0.0, 1.0);
    return (o - (a + ab * t)).distance;
  }

  String? tunnelAt(Offset o, {double tolerance = 14}) {
    String? best;
    var bestD = tolerance;
    for (final t in layout.tunnels) {
      for (var i = 1; i < t.coords.length; i++) {
        final d = distToSegment(o, px(t.coords[i - 1]), px(t.coords[i]));
        if (d < bestD) {
          bestD = d;
          best = t.id;
        }
      }
    }
    return best;
  }

  String? workerAt(Offset o, Iterable<CrisisPosition> positions, {double tolerance = 18}) {
    String? best;
    var bestD = tolerance;
    for (final p in positions) {
      final d = (px(p.point) - o).distance;
      if (d < bestD) {
        bestD = d;
        best = p.userId;
      }
    }
    return best;
  }
}

class CrisisMapPainter extends CustomPainter {
  CrisisMapPainter({required this.layout, required this.colors, required this.positions, required this.statuses, required this.routes, required this.blocked, required this.zoneCodes, this.selected, this.pulse = 0});
  final MineLayoutData layout;
  final MgColors colors;
  final List<CrisisPosition> positions;
  final Map<String, AccountedStatus> statuses;
  final List<CrisisRoute> routes;
  final Set<String> blocked;
  final Set<String> zoneCodes;
  final String? selected;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final proj = CrisisProjection(layout, size);
    final c = colors;
    Path pathOf(List<GeoPoint> pts) {
      final p = Path()..moveTo(proj.px(pts.first).dx, proj.px(pts.first).dy);
      for (final pt in pts.skip(1)) {
        p.lineTo(proj.px(pt).dx, proj.px(pt).dy);
      }
      return p;
    }

    for (final z in layout.zones) {
      final path = Path()..addPolygon(z.ring.map(proj.px).toList(), true);
      final hot = zoneCodes.contains(z.code);
      canvas.drawPath(path, Paint()..color = (hot ? c.crisis : c.slate400).withValues(alpha: hot ? 0.08 : 0.04));
      canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = hot ? 2 : 1..color = hot ? c.crisis : c.slate300);
      _text(canvas, z.code, path.getBounds().topCenter + const Offset(0, 12), c.muted, 11);
    }
    for (final t in layout.tunnels) {
      final p = pathOf(t.coords);
      final isBlocked = t.blocked || blocked.contains(t.id);
      final paint = Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeWidth = math.max(2.5, t.widthM * proj.scale * 0.9)..color = isBlocked ? c.danger : (t.airway == 'intake' ? c.info : c.slate500).withValues(alpha: 0.7);
      if (isBlocked) {
        for (final m in p.computeMetrics()) {
          var d = 0.0;
          while (d < m.length) {
            canvas.drawPath(m.extractPath(d, math.min(d + 7, m.length)), paint);
            d += 12;
          }
        }
      } else {
        canvas.drawPath(p, paint);
      }
    }
    for (final j in layout.junctions) {
      canvas.drawCircle(proj.px(j.point), 2.2, Paint()..color = c.ink700);
    }
    // routes: everyone's recommended route thin; the selected worker's routes bold
    for (final r in routes) {
      if (r.points.length < 2) continue;
      final isSel = r.workerId == selected;
      if (selected != null && !isSel && r.rank != 1) continue;
      canvas.drawPath(
        pathOf(r.points),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = isSel ? (r.rank == 1 ? 6 : 3) : 1.5
          ..color = (isSel ? (r.rank == 1 ? c.success : c.amber500) : c.success).withValues(alpha: isSel ? 0.95 : 0.35),
      );
    }
    for (final e in layout.exits) {
      final o = proj.px(e.point);
      canvas.drawCircle(o, 8, Paint()..color = c.success);
      canvas.drawCircle(o, 8, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.white);
      _text(canvas, e.name, o + const Offset(0, 14), c.text, 10, bold: true);
    }
    for (final r in layout.refuges) {
      canvas.drawRect(Rect.fromCenter(center: proj.px(r.point), width: 13, height: 13), Paint()..color = c.info);
    }
    for (final p in positions) {
      final o = proj.px(p.point);
      final status = statuses[p.userId] ?? AccountedStatus.unknown;
      final color = switch (status) { AccountedStatus.safe => c.success, AccountedStatus.missing => c.danger, AccountedStatus.injured => c.warning, AccountedStatus.unknown => c.slate500 };
      if (p.sos) canvas.drawCircle(o, 10 + 10 * pulse, Paint()..color = c.crisis.withValues(alpha: 0.35 * (1 - pulse)));
      canvas.drawCircle(o, p.userId == selected ? 8 : 6, Paint()..color = color);
      canvas.drawCircle(o, p.userId == selected ? 8 : 6, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.white);
    }
  }

  void _text(Canvas canvas, String s, Offset at, Color color, double size, {bool bold = false}) {
    final tp = TextPainter(text: TextSpan(text: s, style: TextStyle(color: color, fontSize: size, fontWeight: bold ? FontWeight.w700 : FontWeight.w500)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, 0));
  }

  @override
  bool shouldRepaint(CrisisMapPainter o) => true;
}

/// Tappable crisis map. Tapping a worker selects them; tapping a tunnel (when `onTunnel` is set) toggles its blocked state.
class CrisisMap extends StatefulWidget {
  const CrisisMap({super.key, required this.layout, required this.positions, required this.statuses, required this.routes, required this.blocked, required this.zoneCodes, this.selected, this.onWorker, this.onTunnel, this.height = 320});
  final MineLayoutData? layout;
  final List<CrisisPosition> positions;
  final Map<String, AccountedStatus> statuses;
  final List<CrisisRoute> routes;
  final Set<String> blocked;
  final Set<String> zoneCodes;
  final String? selected;
  final ValueChanged<String>? onWorker;
  final ValueChanged<String>? onTunnel;
  final double height;

  @override
  State<CrisisMap> createState() => _CrisisMapState();
}

class _CrisisMapState extends State<CrisisMap> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final layout = widget.layout;
    return Container(
      height: widget.height,
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.card), border: Border.all(color: c.border)),
      clipBehavior: Clip.antiAlias,
      child: layout == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, box) {
              final size = Size(box.maxWidth, box.maxHeight);
              return GestureDetector(
                key: const ValueKey('crisis-map'),
                onTapUp: (d) {
                  final proj = CrisisProjection(layout, size);
                  final w = proj.workerAt(d.localPosition, widget.positions);
                  if (w != null) return widget.onWorker?.call(w);
                  final t = proj.tunnelAt(d.localPosition);
                  if (t != null) widget.onTunnel?.call(t);
                },
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) => CustomPaint(
                    size: size,
                    painter: CrisisMapPainter(layout: layout, colors: c, positions: widget.positions, statuses: widget.statuses, routes: widget.routes, blocked: widget.blocked, zoneCodes: widget.zoneCodes, selected: widget.selected, pulse: _pulse.value),
                  ),
                ),
              );
            }),
    );
  }
}
