import 'dart:ui';

import 'package:flame/components.dart';

import '../../config/game_config.dart';

class WorldBackdrop extends PositionComponent {
  WorldBackdrop()
      : super(
          position: Vector2.zero(),
          size: Vector2(GameConfig.worldWidth, GameConfig.worldHeight),
          priority: 0,
        );

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      size.toRect(),
      Paint()..color = GameConfig.worldFill,
    );
    final grid = Paint()
      ..color = GameConfig.worldGrid
      ..strokeWidth = 1;
    const step = 120.0;
    for (var x = 0.0; x <= GameConfig.worldWidth; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, GameConfig.worldHeight), grid);
    }
    for (var y = 0.0; y <= GameConfig.worldHeight; y += step) {
      canvas.drawLine(Offset(0, y), Offset(GameConfig.worldWidth, y), grid);
    }
    final border = Paint()
      ..color = GameConfig.worldBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawRect(size.toRect().deflate(4), border);
  }
}
