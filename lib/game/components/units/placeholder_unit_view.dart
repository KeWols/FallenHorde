import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../config/game_config.dart';
import '../../models/facing.dart';
import '../../models/faction.dart';
import '../../models/unit_type.dart';
import '../../necromancy_game.dart';
import 'unit_component.dart';

class PlaceholderUnitView extends PositionComponent
    with HasGameReference<NecromancyGame> {
  PlaceholderUnitView({required this.unit})
      : super(
          size: Vector2.all(unit.physicalRadius * 2),
          anchor: Anchor.center,
          position: Vector2.zero(),
        );

  final UnitComponent unit;

  @override
  void update(double dt) {
    final reveal = unit.spawnRevealTimer <= 0
        ? 1.0
        : (1 - unit.spawnRevealTimer / GameConfig.spawnRevealDuration)
            .clamp(0.0, 1.0);
    final punch = unit.hitFlashTimer <= 0
        ? 1.0
        : 1.0 + 0.42 * (unit.hitFlashTimer / GameConfig.hitFlashDuration);
    final emerge = Curves.easeOutBack.transform(reveal.clamp(0.0, 1.0)).clamp(0.0, 1.35);
    scale.setValues(
      (unit.facing == Facing.left ? -1.0 : 1.0) * punch * emerge,
      punch * emerge,
    );
  }

  @override
  void render(Canvas canvas) {
    if (!unit.isAlive) {
      return;
    }
    final r = unit.physicalRadius;
    final reveal = unit.spawnRevealTimer <= 0
        ? 1.0
        : (1 - unit.spawnRevealTimer / GameConfig.spawnRevealDuration)
            .clamp(0.0, 1.0);
    final flashT = unit.hitFlashTimer <= 0
        ? 0.0
        : (unit.hitFlashTimer / GameConfig.hitFlashDuration).clamp(0.0, 1.0);
    final baseFill = unit.faction.isFriendly
        ? GameConfig.friendlyFill
        : GameConfig.enemyFill;
    final fill = flashT > 0
        ? Color.lerp(
            baseFill,
            flashT > 0.55 ? const Color(0xFFFFFFFF) : const Color(0xFFFF2A22),
            flashT,
          )!
        : baseFill;
    final stroke = unit.faction.isFriendly
        ? GameConfig.friendlyStroke
        : GameConfig.enemyStroke;
    final paint = Paint()..color = fill;
    final outline = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;

    canvas.save();
    if (reveal < 0.999) {
      canvas.saveLayer(
        Rect.fromCircle(center: Offset(r, r), radius: r * 2),
        Paint()..color = Color.fromARGB((255 * reveal).round().clamp(0, 255), 255, 255, 255),
      );
    }
    canvas.translate(r, r);
    _drawShape(canvas, unit.type, r, paint);
    _drawShape(canvas, unit.type, r, outline);
    if (flashT > 0) {
      canvas.drawCircle(
        Offset.zero,
        r + 4 + 8 * flashT,
        Paint()
          ..color = const Color(0xFFFF3B30).withValues(alpha: 0.55 * flashT)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 + 3 * flashT,
      );
    }
    if (unit.isRanged) {
      final gem = Paint()
        ..color = flashT > 0
            ? const Color(0xFFFFF1A8)
            : (unit.faction.isFriendly
                ? const Color(0xFFF3E8FF)
                : const Color(0xFFEDEDF2));
      canvas.drawCircle(Offset.zero, r * 0.28, gem);
    }
    canvas.restore();
    if (reveal < 0.999) {
      canvas.restore();
    }
  }

  void _drawShape(Canvas canvas, UnitType type, double r, Paint paint) {
    switch (type) {
      case UnitType.miniKnight:
        canvas.drawCircle(Offset.zero, r, paint);
      case UnitType.mediumKnight:
        canvas.drawCircle(Offset.zero, r, paint);
      case UnitType.wizard:
        final path = Path()
          ..moveTo(0, -r)
          ..lineTo(r * 0.72, 0)
          ..lineTo(0, r)
          ..lineTo(-r * 0.72, 0)
          ..close();
        canvas.drawPath(path, paint);
      case UnitType.heavyKnight:
        canvas.drawRect(Rect.fromCircle(center: Offset.zero, radius: r * 0.92), paint);
      case UnitType.miniGolem:
        canvas.drawPath(_hex(r * 0.95), paint);
      case UnitType.golem:
        canvas.drawPath(_hex(r), paint);
    }
  }

  Path _hex(double r) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = pi / 6 + i * pi / 3;
      final x = cos(a) * r;
      final y = sin(a) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }
}
