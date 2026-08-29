import 'unit_type.dart';

class UnitStats {
  const UnitStats({
    required this.type,
    required this.maxHp,
    required this.damage,
    required this.movementSpeed,
    required this.physicalRadius,
    required this.sightRadius,
    required this.attackRadius,
    required this.attackInterval,
    required this.scoreValue,
    required this.attackKind,
    this.projectileSpeed = 0,
    this.projectilePhysicalRadius = 0,
    this.projectileLifetime = 0,
    this.projectileAttackRange = 0,
  });

  final UnitType type;
  final double maxHp;
  final double damage;
  final double movementSpeed;
  final double physicalRadius;
  final double sightRadius;
  final double attackRadius;
  final double attackInterval;
  final int scoreValue;
  final AttackKind attackKind;
  final double projectileSpeed;
  final double projectilePhysicalRadius;
  final double projectileLifetime;
  final double projectileAttackRange;

  bool get isRanged => attackKind == AttackKind.ranged;
}
