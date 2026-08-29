import 'dart:ui';

import 'package:flame/components.dart';

import '../../config/game_config.dart';
import '../../models/unit_type.dart';
import '../../necromancy_game.dart';

class GraveComponent extends PositionComponent
    with HasGameReference<NecromancyGame> {
  GraveComponent({
    required this.originalUnitType,
    required this.originalSubEnemyId,
    required Vector2 deathPosition,
  }) : super(
          position: deathPosition.clone(),
          size: Vector2.all(GameConfig.graveSize * 2),
          anchor: Anchor.center,
          priority: 4,
        );

  final UnitType originalUnitType;
  final int originalSubEnemyId;

  @override
  void onMount() {
    super.onMount();
    game.world.registerGrave(this);
  }

  @override
  void onRemove() {
    game.world.unregisterGrave(this);
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = GameConfig.graveFill;
    final w = GameConfig.graveSize;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w, w), width: w * 0.7, height: w * 1.15),
        const Radius.circular(2),
      ),
      paint,
    );
    final top = Paint()..color = const Color(0xFF8A8490);
    canvas.drawCircle(Offset(w, w * 0.42), w * 0.22, top);
  }
}
