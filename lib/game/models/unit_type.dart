enum UnitType {
  miniKnight,
  mediumKnight,
  wizard,
  heavyKnight,
  miniGolem,
  golem,
}

enum AttackKind { melee, ranged }

extension UnitTypeX on UnitType {
  String get shortLabel {
    switch (this) {
      case UnitType.miniKnight:
        return 'm';
      case UnitType.mediumKnight:
        return 'M';
      case UnitType.wizard:
        return 'W';
      case UnitType.heavyKnight:
        return 'H';
      case UnitType.miniGolem:
        return 'g';
      case UnitType.golem:
        return 'G';
    }
  }

  String get displayName {
    switch (this) {
      case UnitType.miniKnight:
        return 'Mini Knight';
      case UnitType.mediumKnight:
        return 'Medium Knight';
      case UnitType.wizard:
        return 'Wizard';
      case UnitType.heavyKnight:
        return 'Heavy Knight';
      case UnitType.miniGolem:
        return 'Mini Golem';
      case UnitType.golem:
        return 'Golem';
    }
  }
}
