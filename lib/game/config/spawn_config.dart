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

class SlotPlan {
  const SlotPlan({
    required this.weak,
    required this.normal,
    required this.strong,
    required this.deadly,
  });

  final int weak;
  final int normal;
  final int strong;
  final int deadly;

  int of(DifficultyCategory category) {
    switch (category) {
      case DifficultyCategory.weak:
        return weak;
      case DifficultyCategory.normal:
        return normal;
      case DifficultyCategory.strong:
        return strong;
      case DifficultyCategory.deadly:
        return deadly;
    }
  }
}

/// Slot counts, score-budget bands, unit unlocks, and archetype mix tables
/// used by [SpawnSystem.generateComposition].
class SpawnConfig {
  SpawnConfig._();

  /// How many squads of each threat band should exist, based on run progress.
  /// Late game: fewer packs, each can be much larger.
  static SlotPlan slotPlan(int maxScore) {
    if (maxScore < 25) {
      return const SlotPlan(weak: 5, normal: 3, strong: 2, deadly: 1);
    }
    if (maxScore < 80) {
      return const SlotPlan(weak: 4, normal: 3, strong: 3, deadly: 2);
    }
    if (maxScore < 220) {
      return const SlotPlan(weak: 3, normal: 3, strong: 3, deadly: 2);
    }
    if (maxScore < 700) {
      return const SlotPlan(weak: 2, normal: 2, strong: 3, deadly: 2);
    }
    if (maxScore < 2500) {
      return const SlotPlan(weak: 1, normal: 2, strong: 2, deadly: 2);
    }
    return const SlotPlan(weak: 1, normal: 1, strong: 2, deadly: 2);
  }

  static int unitCap(DifficultyCategory category, int currentScore) {
    final current = currentScore < 1 ? 1 : currentScore;
    final raw = switch (category) {
      DifficultyCategory.weak => 8 + current / 90,
      DifficultyCategory.normal => 16 + current / 48,
      DifficultyCategory.strong => 26 + current / 22,
      DifficultyCategory.deadly => 36 + current / 14,
    };
    final ceiling = switch (category) {
      DifficultyCategory.weak => 28,
      DifficultyCategory.normal => 90,
      DifficultyCategory.strong => 150,
      DifficultyCategory.deadly => 180,
    };
    return raw.round().clamp(4, ceiling);
  }

  static int slotsFor(DifficultyCategory category, int maxScore) {
    return slotPlan(maxScore).of(category);
  }

  /// Score-budget vs the living army ([currentScore]).
  static const double weakBudgetMinFactor = 0.22;
  static const double weakBudgetMaxFactor = 0.48;
  static const double evenBudgetMinFactor = 0.82;
  static const double evenBudgetMaxFactor = 1.18;
  static const double strongBudgetMinFactor = 1.40;
  static const double strongBudgetMaxFactor = 1.95;
  static const double deadlyBudgetMinFactor = 2.30;
  static const double deadlyBudgetMaxFactor = 3.50;
  static const double budgetVariance = 0.10;

  static const double pingPongChance = 0.50;
  static const double minimumSpawnDistanceFromPlayer = 520;
  static const double spawnMapMargin = 340;
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
    SquadArchetype.titan: 7,
    SquadArchetype.mixed: 12,
    SquadArchetype.rangedBall: 8,
    SquadArchetype.tankWall: 6,
  };

  static const Map<SquadArchetype, int> minUnitCounts = {
    SquadArchetype.swarm: 6,
    SquadArchetype.knightLine: 4,
    SquadArchetype.casterEscort: 5,
    SquadArchetype.heavyLine: 4,
    SquadArchetype.golemEscort: 4,
    SquadArchetype.titan: 3,
    SquadArchetype.mixed: 5,
    SquadArchetype.rangedBall: 3,
    SquadArchetype.tankWall: 2,
  };

  static const Map<SquadArchetype, int> maxUnitCounts = {
    SquadArchetype.swarm: 28,
    SquadArchetype.knightLine: 16,
    SquadArchetype.casterEscort: 18,
    SquadArchetype.heavyLine: 14,
    SquadArchetype.golemEscort: 16,
    SquadArchetype.titan: 12,
    SquadArchetype.mixed: 20,
    SquadArchetype.rangedBall: 14,
    SquadArchetype.tankWall: 10,
  };

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
      UnitType.miniKnight: 0.30,
      UnitType.heavyKnight: 0.20,
    },
    SquadArchetype.heavyLine: {
      UnitType.heavyKnight: 0.52,
      UnitType.mediumKnight: 0.30,
      UnitType.wizard: 0.10,
      UnitType.miniKnight: 0.08,
    },
    SquadArchetype.golemEscort: {
      UnitType.miniGolem: 0.22,
      UnitType.heavyKnight: 0.24,
      UnitType.mediumKnight: 0.26,
      UnitType.wizard: 0.12,
      UnitType.miniKnight: 0.16,
    },
    SquadArchetype.titan: {
      UnitType.golem: 0.12,
      UnitType.heavyKnight: 0.24,
      UnitType.wizard: 0.16,
      UnitType.mediumKnight: 0.20,
      UnitType.miniGolem: 0.10,
      UnitType.miniKnight: 0.18,
    },
    SquadArchetype.mixed: {
      UnitType.miniKnight: 0.18,
      UnitType.mediumKnight: 0.22,
      UnitType.wizard: 0.16,
      UnitType.heavyKnight: 0.18,
      UnitType.miniGolem: 0.16,
      UnitType.golem: 0.10,
    },
    SquadArchetype.rangedBall: {
      UnitType.wizard: 0.38,
      UnitType.miniKnight: 0.28,
      UnitType.mediumKnight: 0.18,
      UnitType.heavyKnight: 0.16,
    },
    SquadArchetype.tankWall: {
      UnitType.golem: 0.16,
      UnitType.miniGolem: 0.22,
      UnitType.heavyKnight: 0.18,
      UnitType.wizard: 0.22,
      UnitType.miniKnight: 0.14,
      UnitType.mediumKnight: 0.08,
    },
  };
}
