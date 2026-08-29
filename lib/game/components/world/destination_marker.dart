import 'dart:ui';

import 'package:flame/components.dart';

class DestinationMarker extends PositionComponent {
  DestinationMarker()
      : super(
          size: Vector2.all(18),
          anchor: Anchor.center,
          priority: 3,
        );

  bool visibleMarker = false;

  void showAt(Vector2 worldPosition) {
    position.setFrom(worldPosition);
    visibleMarker = true;
  }

  void hideMarker() {
    visibleMarker = false;
  }

  @override
  void render(Canvas canvas) {
    if (!visibleMarker) {
      return;
    }
    final paint = Paint()
      ..color = const Color(0x88F0E6C8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(const Offset(9, 9), 7, paint);
    canvas.drawLine(const Offset(9, 1), const Offset(9, 17), paint);
    canvas.drawLine(const Offset(1, 9), const Offset(17, 9), paint);
  }
}
