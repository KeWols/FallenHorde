import 'package:flame/components.dart';

import '../components/effects/damage_popup.dart';
import '../components/projectiles/projectile_component.dart';
import '../components/units/unit_component.dart';
import '../config/game_config.dart';
import '../models/facing.dart';
import '../necromancy_game.dart';

class CombatSystem {
  CombatSystem(this.game);

  final NecromancyGame game;
  final List<ProjectileComponent> _pool = [];

  void reset() {
    for (final projectile in game.world.projectiles.toList()) {
      projectile.removeFromParent();
    }
    _pool.clear();
  }

  bool tryAttack(UnitComponent attacker, UnitComponent target) {
    if (!attacker.isAlive || !target.isAlive) {
      return false;
    }
    if (attacker.attackCooldown > 0) {
      return false;
    }
    if (!game.targeting.inAttackRange(attacker, target)) {
      return false;
    }
    attacker.attackCooldown = attacker.stats.attackInterval;
    attacker.committedAttackTimer = GameConfig.committedAttackDuration;
    if (attacker.isRanged) {
      _launchProjectile(attacker, target);
    } else {
      _applyDamage(attacker, target);
    }
    return true;
  }

  void tickProjectiles(double dt) {
    for (final projectile in game.world.projectiles.toList()) {
      projectile.tick(dt);
    }
  }

  void handleProjectileCollision(ProjectileComponent projectile) {
    final nearby = game.spatial.queryRadius(
      projectile.position,
      projectile.radius + 28,
    );
    UnitComponent? hit;
    var hitDist = double.infinity;
    for (final unit in nearby) {
      if (!unit.isAlive || unit.faction == projectile.ownerFaction) {
        continue;
      }
      final reach = projectile.radius + unit.physicalRadius;
      final dist = projectile.position.distanceToSquared(unit.position);
      if (dist <= reach * reach && dist < hitDist) {
        hitDist = dist;
        hit = unit;
      }
    }
    if (hit == null) {
      return;
    }
    hit.takeDamage(projectile.damage);
    game.world.add(
      DamagePopup(
        worldPosition: hit.position + Vector2(0, -hit.physicalRadius - 8),
        amount: hit.lastDamageTaken.round().clamp(1, 999),
      ),
    );
    despawnProjectile(projectile);
    if (!hit.isAlive) {
      game.necromancy.handleDeath(hit);
    }
  }

  void despawnProjectile(ProjectileComponent projectile) {
    projectile.inUse = false;
    projectile.removeFromParent();
    _pool.add(projectile);
  }

  void _launchProjectile(UnitComponent wizard, UnitComponent target) {
    final dir = target.position - wizard.position;
    if (dir.length2 == 0) {
      dir.setValues(wizard.facing == Facing.right ? 1 : -1, 0);
    }
    final projectile = _pool.isEmpty ? ProjectileComponent() : _pool.removeLast();
    projectile.launch(
      origin: wizard.position.clone(),
      dir: dir,
      faction: wizard.faction,
      projectileDamage: wizard.stats.damage,
      projectileSpeed: wizard.stats.projectileSpeed,
      projectileRadius: wizard.stats.projectilePhysicalRadius,
      projectileLifetime: wizard.stats.projectileLifetime,
    );
    game.world.add(projectile);
  }

  void _applyDamage(UnitComponent attacker, UnitComponent target) {
    target.takeDamage(attacker.stats.damage);
    _spawnDamagePopup(target);
    if (!target.isAlive) {
      game.necromancy.handleDeath(target);
    }
  }

  void _spawnDamagePopup(UnitComponent target) {
    game.world.add(
      DamagePopup(
        worldPosition: target.position + Vector2(0, -target.physicalRadius - 8),
        amount: target.lastDamageTaken.round().clamp(1, 999),
      ),
    );
  }
}
