import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../models/projectile_style.dart';

class ProjectileImpactEffect extends PositionComponent {
  ProjectileImpactEffect({
    required Vector2 worldPosition,
    required this.style,
  })  : _motes = _createMotes(worldPosition),
        super(
          position: worldPosition.clone(),
          size: Vector2.all(72),
          anchor: Anchor.center,
          priority: 22,
        );

  final ProjectileStyle style;
  final List<_BurstMote> _motes;
  double _age = 0;

  static const duration = 0.58;

  static List<_BurstMote> _createMotes(Vector2 origin) {
    final rng = Random(origin.x.round() * 19349663 ^ origin.y.round() * 83492791);
    return List.generate(16, (i) {
      final a = (i / 16) * pi * 2 + rng.nextDouble() * 0.4;
      return _BurstMote(
        angle: a,
        speed: 38 + rng.nextDouble() * 70,
        radius: 1.3 + rng.nextDouble() * 2.4,
        spin: (rng.nextDouble() - 0.5) * 8,
      );
    });
  }

  @override
  void update(double dt) {
    _age += dt;
    if (_age >= duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final t = (_age / duration).clamp(0.0, 1.0);
    final pop = Curves.easeOutCubic.transform((t / 0.38).clamp(0.0, 1.0));
    final fade = t < 0.45 ? 1.0 : 1 - ((t - 0.45) / 0.55);
    final bloom = sin(t * pi).clamp(0.0, 1.0);
    final c = Offset(size.x / 2, size.y / 2);

    final shock = 10.0 + 34 * pop;
    canvas.drawCircle(
      c,
      shock,
      Paint()
        ..color = style.impactHot.withValues(alpha: 0.55 * fade * bloom)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2 + 2.4 * (1 - pop)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(
      c,
      shock * 0.62,
      Paint()
        ..color = style.impactCool.withValues(alpha: 0.42 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    final core = Paint()
      ..shader = RadialGradient(
        colors: [
          style.impactHot.withValues(alpha: 0.9 * fade * bloom),
          style.glow.withValues(alpha: 0.45 * fade),
          const Color(0x00000000),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: 16 + 10 * bloom));
    canvas.drawCircle(c, 7 + 9 * bloom * (1 - t), core);

    for (final mote in _motes) {
      final dist = _age * mote.speed * Curves.easeOutQuad.transform(pop);
      final a = mote.angle + _age * mote.spin;
      final p = Offset(c.dx + cos(a) * dist, c.dy + sin(a) * dist);
      final alpha = (fade * 0.95).clamp(0.0, 1.0);
      canvas.drawCircle(
        p,
        mote.radius * (1.15 - 0.55 * t),
        Paint()..color = style.spark.withValues(alpha: alpha),
      );
    }
  }
}

class _BurstMote {
  const _BurstMote({
    required this.angle,
    required this.speed,
    required this.radius,
    required this.spin,
  });

  final double angle;
  final double speed;
  final double radius;
  final double spin;
}
