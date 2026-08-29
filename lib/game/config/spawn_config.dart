import '../models/difficulty.dart';
import '../models/squad_archetype.dart';
import '../models/unit_type.dart';

class UnlockThresholds {
  const UnlockThresholds({
    required this.rareAt,
    required this.commonAt,
  });

  final double rareAt;
  final double commonAt;
}

class SpawnConfig {
  SpawnConfig._();

  static const int weakSlots = 7;
  static const int normalSlots = 3;
  static const int strongSlots = 2;
  static const int deadlySlots = 1;

  static int slotsFor(DifficultyCategory category) {
    switch (category) {
      case DifficultyCategory.weak:
        return weakSlots;
      case DifficultyCategory.normal:
        return normalSlots;
      case DifficultyCategory.strong:
        return strongSlots;
      case DifficultyCategory.deadly:
        return deadlySlots;
    }
  }

  static const double weakBudgetMinFactor = 0.35;
  static const double weakBudgetMaxFactor = 0.75;
  static const double budgetVariance = 0.08;

  static const double pingPongChance = 0.50;
  static const double minimumSpawnDistanceFromPlayer = 520;
  static const double spawnMapMargin = 220;
  static const double replacementDelayMin = 1.6;
  static const double replacementDelayMax = 3.4;
  static const int spawnLocationAttempts = 40;

  static const Map<UnitType, UnlockThresholds> unlocks = {
    UnitType.miniKnight: UnlockThresholds(rareAt: 0, commonAt: 0),
    UnitType.mediumKnight: UnlockThresholds(rareAt: 15, commonAt: 40),
    UnitType.wizard: UnlockThresholds(rareAt: 70, commonAt: 160),
    UnitType.heavyKnight: UnlockThresholds(rareAt: 130, commonAt: 300),
    UnitType.miniGolem: UnlockThresholds(rareAt: 350, commonAt: 750),
    UnitType.golem: UnlockThresholds(rareAt: 1000, commonAt: 2200),
  };

  static const Map<SquadArchetype, int> preferredUnitCounts = {
    SquadArchetype.swarm: 16,
    SquadArchetype.knightLine: 10,
    SquadArchetype.casterEscort: 12,
    SquadArchetype.heavyLine: 9,
    SquadArchetype.golemEscort: 11,
    SquadArchetype.titan: 8,
    SquadArchetype.mixed: 12,
  };

  static const Map<SquadArchetype, int> minUnitCounts = {
    SquadArchetype.swarm: 6,
    SquadArchetype.knightLine: 4,
    SquadArchetype.casterEscort: 5,
    SquadArchetype.heavyLine: 4,
    SquadArchetype.golemEscort: 4,
    SquadArchetype.titan: 3,
    SquadArchetype.mixed: 5,
  };

  static const Map<SquadArchetype, int> maxUnitCounts = {
    SquadArchetype.swarm: 28,
    SquadArchetype.knightLine: 16,
    SquadArchetype.casterEscort: 18,
    SquadArchetype.heavyLine: 14,
    SquadArchetype.golemEscort: 16,
    SquadArchetype.titan: 12,
    SquadArchetype.mixed: 20,
  };

  /// Ratio templates. Missing types are treated as 0.
  static const Map<SquadArchetype, Map<UnitType, double>> archetypeRatios = {
    SquadArchetype.swarm: {
      UnitType.miniKnight: 0.86,
      UnitType.mediumKnight: 0.14,
    },
    SquadArchetype.knightLine: {
      UnitType.mediumKnight: 0.58,
      UnitType.miniKnight: 0.22,
      UnitType.heavyKnight: 0.20,
    },
    SquadArchetype.casterEscort: {
      UnitType.wizard: 0.18,
      UnitType.mediumKnight: 0.32,
      UnitType.miniKnight: 0.38,
      UnitType.heavyKnight: 0.12,
    },
    SquadArchetype.heavyLine: {
      UnitType.heavyKnight: 0.52,
      UnitType.mediumKnight: 0.30,
      UnitType.wizard: 0.10,
      UnitType.miniKnight: 0.08,
    },
    SquadArchetype.golemEscort: {
      UnitType.miniGolem: 0.18,
      UnitType.heavyKnight: 0.22,
      UnitType.mediumKnight: 0.28,
      UnitType.wizard: 0.10,
      UnitType.miniKnight: 0.22,
    },
    SquadArchetype.titan: {
      UnitType.golem: 0.16,
      UnitType.heavyKnight: 0.28,
      UnitType.wizard: 0.18,
      UnitType.mediumKnight: 0.26,
      UnitType.miniGolem: 0.12,
    },
    SquadArchetype.mixed: {
      UnitType.miniKnight: 0.22,
      UnitType.mediumKnight: 0.22,
      UnitType.wizard: 0.14,
      UnitType.heavyKnight: 0.18,
      UnitType.miniGolem: 0.14,
      UnitType.golem: 0.10,
    },
  };
}
