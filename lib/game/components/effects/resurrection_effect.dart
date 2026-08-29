import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../config/game_config.dart';
import '../../models/unit_type.dart';
import '../../necromancy_game.dart';

class ResurrectionEffect extends PositionComponent
    with HasGameReference<NecromancyGame> {
  ResurrectionEffect({
    required this.originalUnitType,
    required Vector2 gravePosition,
    this.delay = 0,
    required this.onEmerge,
  })  : _motes = _createMotes(gravePosition),
        super(
          position: gravePosition.clone(),
          size: Vector2(64, 96),
          anchor: Anchor.center,
          priority: 20,
        ) {
    _wait = delay;
  }

  final UnitType originalUnitType;
  final double delay;
  final VoidCallback onEmerge;
  final List<_Mote> _motes;

  double _wait = 0;
  double _age = 0;
  bool _emerged = false;

  static const duration = GameConfig.resurrectionDuration;

  static List<_Mote> _createMotes(Vector2 origin) {
    final rng = Random(origin.x.round() * 73856093 ^ origin.y.round());
    return List.generate(14, (i) {
      return _Mote(
        x: (rng.nextDouble() - 0.5) * 18,
        speed: 28 + rng.nextDouble() * 46,
        radius: 1.4 + rng.nextDouble() * 2.2,
        phase: rng.nextDouble() * pi * 2,
        sway: 6 + rng.nextDouble() * 10,
      );
    });
  }

  @override
  void onRemove() {
    _emerged = true;
    super.onRemove();
  }

  @override
  void update(double dt) {
    if (!isMounted) {
      return;
    }
    if (_wait > 0) {
      _wait -= dt;
      return;
    }
    _age += dt;
    if (!_emerged && _age >= duration * 0.42) {
      _emerged = true;
      onEmerge();
    }
    if (_age >= duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (_wait > 0) {
      _drawGrave(canvas, 1);
      return;
    }
    final t = (_age / duration).clamp(0.0, 1.0);
    final rise = Curves.easeOutCubic.transform((t / 0.55).clamp(0.0, 1.0));
    final fade = t < 0.7 ? 1.0 : 1 - ((t - 0.7) / 0.3);
    final bloom = sin(t * pi).clamp(0.0, 1.0);
    final cx = size.x / 2;
    final cy = size.y * 0.72;

    final ground = Paint()
      ..shader = RadialGradient(
        colors: [
          GameConfig.resurrectionLight.withValues(alpha: 0.55 * bloom),
          GameConfig.friendlyFill.withValues(alpha: 0.18 * bloom),
          const Color(0x00000000),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 34));
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 4), width: 52, height: 18),
      ground,
    );

    final shaftHeight = 18.0 + 70 * rise;
    final shaft = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          GameConfig.resurrectionLight.withValues(alpha: 0.0),
          GameConfig.resurrectionLight.withValues(alpha: 0.85 * bloom),
          GameConfig.friendlyFill.withValues(alpha: 0.55 * bloom),
          const Color(0x00FFFFFF),
        ],
        stops: const [0, 0.12, 0.45, 1],
      ).createShader(
        Rect.fromLTWH(cx - 10, cy - shaftHeight, 20, shaftHeight),
      );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy - shaftHeight / 2),
          width: 10 + 6 * bloom,
          height: shaftHeight,
        ),
        const Radius.circular(8),
      ),
      shaft,
    );

    final core = Paint()
      ..color = Colors.white.withValues(alpha: 0.7 * bloom)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(cx, cy - 8 * rise), 4.5 + 3 * bloom, core);

    for (final mote in _motes) {
      final my = cy - (_age * mote.speed);
      final mx = cx + mote.x + sin(_age * 8 + mote.phase) * mote.sway * (1 - t);
      final alpha = ((1 - t) * 0.9).clamp(0.0, 1.0);
      if (alpha <= 0 || my < 4) {
        continue;
      }
      canvas.drawCircle(
        Offset(mx, my),
        mote.radius * (0.7 + bloom * 0.6),
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }

    _drawGrave(canvas, fade * (1 - rise * 0.85));
  }

  void _drawGrave(Canvas canvas, double opacity) {
    if (opacity <= 0.02) {
      return;
    }
    final w = GameConfig.graveSize;
    final cx = size.x / 2;
    final cy = size.y * 0.72;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: w * 0.7,
          height: w * 1.15,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = GameConfig.graveFill.withValues(alpha: opacity),
    );
    canvas.drawCircle(
      Offset(cx, cy - w * 0.28),
      w * 0.22,
      Paint()..color = const Color(0xFF8A8490).withValues(alpha: opacity),
    );
  }
}

class _Mote {
  const _Mote({
    required this.x,
    required this.speed,
    required this.radius,
    required this.phase,
    required this.sway,
  });

  final double x;
  final double speed;
  final double radius;
  final double phase;
  final double sway;
}
