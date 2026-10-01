import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../data/models/review_models.dart';

/// Photo with an optional YOLO / AI region overlay. Region coordinates are fractions (0..1) of the image.
class PhotoPanel extends StatefulWidget {
  const PhotoPanel({super.key, required this.url, required this.aspect, required this.items, required this.yolo});
  final String? url;
  final double aspect;
  final List<AiItem> items;
  final List<YoloBox> yolo;

  @override
  State<PhotoPanel> createState() => _PhotoPanelState();
}

class _PhotoPanelState extends State<PhotoPanel> {
  bool _boxes = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final hasBoxes = widget.yolo.isNotEmpty || widget.items.any((i) => i.region != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.card),
          child: AspectRatio(
            aspectRatio: widget.aspect <= 0 ? 0.75 : widget.aspect,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (widget.url == null)
                  ColoredBox(color: c.slate100, child: Icon(Icons.image_not_supported, color: c.muted, size: 40))
                else
                  Image.network(widget.url!, fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: c.slate100, child: Icon(Icons.broken_image, color: c.muted, size: 40))),
                if (_boxes) CustomPaint(painter: BoxOverlayPainter(items: widget.items, yolo: widget.yolo, aiColor: c.amber500, yoloColor: c.info)),
              ],
            ),
          ),
        ),
        if (hasBoxes)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: Space.sm),
              child: FilterChip(
                label: const Text('Show detection boxes'),
                selected: _boxes,
                onSelected: (v) => setState(() => _boxes = v),
              ),
            ),
          ),
      ],
    );
  }
}

class BoxOverlayPainter extends CustomPainter {
  BoxOverlayPainter({required this.items, required this.yolo, required this.aiColor, required this.yoloColor});
  final List<AiItem> items;
  final List<YoloBox> yolo;
  final Color aiColor, yoloColor;

  @override
  void paint(Canvas canvas, Size size) {
    void draw(ItemRegion r, Color color, String label) {
      final rect = Rect.fromLTWH(r.x * size.width, r.y * size.height, r.w * size.width, r.h * size.height);
      canvas.drawRect(rect, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = color);
      final tp = TextPainter(text: TextSpan(text: label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, backgroundColor: Colors.black54)), textDirection: TextDirection.ltr)..layout(maxWidth: size.width);
      tp.paint(canvas, rect.topLeft + const Offset(2, 2));
    }

    for (final i in items) {
      if (i.region != null) draw(i.region!, aiColor, i.key.label);
    }
    for (final y in yolo) {
      draw(y.region, yoloColor, '${y.label} ${(y.confidence * 100).round()}%');
    }
  }

  @override
  bool shouldRepaint(BoxOverlayPainter old) => old.items != items || old.yolo != yolo;
}
