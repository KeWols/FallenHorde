import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../config/game_config.dart';
import '../../models/faction.dart';
import '../../models/projectile_style.dart';
import '../../necromancy_game.dart';

class ProjectileComponent extends PositionComponent
    with HasGameReference<NecromancyGame> {
  ProjectileComponent()
      : super(
          size: Vector2.all(28),
          anchor: Anchor.center,
          priority: 12,
        );

  Faction ownerFaction = Faction.friendly;
  ProjectileStyle style = ProjectileCatalog.white;
  double damage = 0;
  double speed = 0;
  double hitRadius = 4.5;
  double lifetime = 0;
  double age = 0;
  final Vector2 direction = Vector2(1, 0);
  bool inUse = false;
  final List<_TrailDot> _trail = [];

  double get radius => hitRadius;

  void launch({
    required Vector2 origin,
    required Vector2 dir,
    required Faction faction,
    required ProjectileStyle style,
    required double projectileDamage,
    required double projectileSpeed,
    required double projectileRadius,
    required double projectileLifetime,
  }) {
    inUse = true;
    age = 0;
    lifetime = projectileLifetime;
    ownerFaction = faction;
    this.style = style;
    damage = projectileDamage;
    speed = projectileSpeed;
    hitRadius = projectileRadius;
    position.setFrom(origin);
    direction
      ..setFrom(dir)
      ..normalize();
    _trail.clear();
  }

  @override
  void onMount() {
    super.onMount();
    game.world.registerProjectile(this);
  }

  @override
  void onRemove() {
    game.world.unregisterProjectile(this);
    super.onRemove();
  }

  void tick(double dt) {
    if (!inUse) {
      return;
    }
    age += dt;
    position += direction * speed * dt;
    _emitTrail();
    if (age >= lifetime || !WorldBounds.contains(position)) {
      game.combat.despawnProjectile(this);
      return;
    }
    game.combat.handleProjectileCollision(this);
  }

  void _emitTrail() {
    if (_trail.length > 10) {
      _trail.removeAt(0);
    }
    _trail.add(_TrailDot());
  }

  @override
  void render(Canvas canvas) {
    if (!inUse) {
      return;
    }
    final c = Offset(size.x / 2, size.y / 2);
    final ang = atan2(direction.y, direction.x);
    final pulse = 0.72 + 0.28 * sin(age * 18);

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(ang);

    for (var i = 0; i < _trail.length; i++) {
      final u = i / max(1, _trail.length);
      final fade = u * 0.55;
      canvas.drawCircle(
        Offset(-8.0 - i * 2.1, sin(age * 14 + i) * 1.4),
        1.6 + (1 - u) * 1.8,
        Paint()..color = style.trail.withValues(alpha: fade),
      );
    }

    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 18, height: 7),
      Paint()
        ..color = style.glow.withValues(alpha: 0.38 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 13, height: 4.2),
        const Radius.circular(3),
      ),
      Paint()..color = style.glow.withValues(alpha: 0.85),
    );
    canvas.drawCircle(
      const Offset(5.2, 0),
      2.6 * pulse,
      Paint()..color = style.core,
    );
    canvas.restore();
  }
}

class _TrailDot {
  _TrailDot();
}
