import '../models/unit_stats.dart';
import '../models/unit_type.dart';

/// All per-type combat stats. Change values here rather than in AI or combat.
class UnitCatalog {
  UnitCatalog._();

  static const Map<UnitType, UnitStats> byType = {
    UnitType.miniKnight: UnitStats(
      type: UnitType.miniKnight,
      maxHp: 3,
      damage: 1,
      movementSpeed: 86,
      physicalRadius: 8,
      sightRadius: 92,
      attackRadius: 18,
      attackInterval: 0.85,
      scoreValue: 1,
      attackKind: AttackKind.melee,
    ),
    UnitType.mediumKnight: UnitStats(
      type: UnitType.mediumKnight,
      maxHp: 10,
      damage: 2,
      movementSpeed: 78,
      physicalRadius: 11,
      sightRadius: 100,
      attackRadius: 20,
      attackInterval: 1.00,
      scoreValue: 10,
      attackKind: AttackKind.melee,
    ),
    UnitType.wizard: UnitStats(
      type: UnitType.wizard,
      maxHp: 15,
      damage: 3,
      movementSpeed: 72,
      physicalRadius: 10,
      sightRadius: 96,
      attackRadius: 210,
      attackInterval: 1.50,
      scoreValue: 18,
      attackKind: AttackKind.ranged,
      projectileSpeed: 280,
      projectilePhysicalRadius: 4.5,
      projectileLifetime: 10,
      projectileAttackRange: 210,
    ),
    UnitType.heavyKnight: UnitStats(
      type: UnitType.heavyKnight,
      maxHp: 20,
      damage: 3,
      movementSpeed: 64,
      physicalRadius: 13,
      sightRadius: 98,
      attackRadius: 22,
      attackInterval: 1.10,
      scoreValue: 25,
      attackKind: AttackKind.melee,
    ),
    UnitType.miniGolem: UnitStats(
      type: UnitType.miniGolem,
      maxHp: 50,
      damage: 4,
      movementSpeed: 52,
      physicalRadius: 17,
      sightRadius: 90,
      attackRadius: 24,
      attackInterval: 1.30,
      scoreValue: 60,
      attackKind: AttackKind.melee,
    ),
    UnitType.golem: UnitStats(
      type: UnitType.golem,
      maxHp: 100,
      damage: 6,
      movementSpeed: 42,
      physicalRadius: 23,
      sightRadius: 88,
      attackRadius: 28,
      attackInterval: 1.55,
      scoreValue: 150,
      attackKind: AttackKind.melee,
    ),
  };

  static UnitStats stats(UnitType type) => byType[type]!;
}
