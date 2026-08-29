enum Faction { friendly, enemy }

extension FactionX on Faction {
  bool get isFriendly => this == Faction.friendly;
  bool get isEnemy => this == Faction.enemy;

  bool isHostileTo(Faction other) => this != other;
}
