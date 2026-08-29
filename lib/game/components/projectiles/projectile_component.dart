import 'dart:ui';

import 'package:flame/components.dart';

import '../../config/game_config.dart';
import '../../models/faction.dart';
import '../../necromancy_game.dart';

class ProjectileComponent extends CircleComponent
    with HasGameReference<NecromancyGame> {
  ProjectileComponent()
      : super(
          radius: 4,
          anchor: Anchor.center,
          paint: Paint()..color = const Color(0xFFE7D36A),
          priority: 12,
        );

  Faction ownerFaction = Faction.friendly;
  double damage = 0;
  double speed = 0;
  double lifetime = 0;
  double age = 0;
  final Vector2 direction = Vector2(1, 0);
  bool inUse = false;

  void launch({
    required Vector2 origin,
    required Vector2 dir,
    required Faction faction,
    required double projectileDamage,
    required double projectileSpeed,
    required double projectileRadius,
    required double projectileLifetime,
  }) {
    inUse = true;
    age = 0;
    lifetime = projectileLifetime;
    ownerFaction = faction;
    damage = projectileDamage;
    speed = projectileSpeed;
    radius = projectileRadius;
    size = Vector2.all(projectileRadius * 2);
    position.setFrom(origin);
    direction
      ..setFrom(dir)
      ..normalize();
    paint.color = faction.isFriendly
        ? const Color(0xFFB6FF7A)
        : const Color(0xFFFFC14D);
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
    if (age >= lifetime || !WorldBounds.contains(position)) {
      game.combat.despawnProjectile(this);
      return;
    }
    game.combat.handleProjectileCollision(this);
  }
}
