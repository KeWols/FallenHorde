import 'package:flame/components.dart';

import 'components/graves/grave_component.dart';
import 'components/projectiles/projectile_component.dart';
import 'components/units/unit_component.dart';

class GameWorld extends World {
  final List<UnitComponent> units = [];
  final List<GraveComponent> graves = [];
  final List<ProjectileComponent> projectiles = [];

  void registerUnit(UnitComponent unit) {
    if (!units.contains(unit)) {
      units.add(unit);
    }
  }

  void unregisterUnit(UnitComponent unit) {
    units.remove(unit);
  }

  void registerGrave(GraveComponent grave) {
    if (!graves.contains(grave)) {
      graves.add(grave);
    }
  }

  void unregisterGrave(GraveComponent grave) {
    graves.remove(grave);
  }

  void registerProjectile(ProjectileComponent projectile) {
    if (!projectiles.contains(projectile)) {
      projectiles.add(projectile);
    }
  }

  void unregisterProjectile(ProjectileComponent projectile) {
    projectiles.remove(projectile);
  }

  List<UnitComponent> get living =>
      units.where((unit) => unit.isAlive).toList(growable: false);

  List<UnitComponent> get livingFriendlies => living
      .where((unit) => unit.isFriendly)
      .toList(growable: false);

  List<UnitComponent> get livingEnemies =>
      living.where((unit) => unit.isEnemy).toList(growable: false);
}
