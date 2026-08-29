import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../components/units/unit_component.dart';
import '../config/game_config.dart';
import '../config/spawn_config.dart';
import '../config/unit_definitions.dart';
import '../models/ai_state.dart';
import '../models/difficulty.dart';
import '../models/enemy_squad.dart';
import '../models/faction.dart';
import '../models/patrol_type.dart';
import '../models/squad_archetype.dart';
import '../models/unit_type.dart';
import '../necromancy_game.dart';
import '../services/game_rng.dart';
import 'squad_system.dart';

class _PendingReplacement {
  _PendingReplacement(this.category, this.delay);
  final DifficultyCategory category;
  double delay;
}

/// Enemy horde generation and replacement.
///
/// Core algorithm:
/// - [generateComposition] — public entry (category + living score + peak score)
/// - [_budget] / [_allowedTypes] / [_pickArchetype] / [_fillCounts]
///
/// Tunables: `lib/game/config/spawn_config.dart`
/// Per-unit score, HP, damage: `lib/game/config/unit_definitions.dart`
class SpawnSystem {
  SpawnSystem(this.game);

  final NecromancyGame game;
  final List<_PendingReplacement> _pending = [];

  void reset() {
    _pending.clear();
  }

  void populateInitial() {
    final plan = SpawnConfig.slotPlan(game.score.maxScore);
    for (final category in DifficultyCategory.values) {
      for (var i = 0; i < plan.of(category); i++) {
        spawnSquad(category);
      }
    }
  }

  void tick(double dt) {
    _tickPatrols();
    for (final pending in _pending) {
      pending.delay -= dt;
    }
    final due = _pending.where((p) => p.delay <= 0).toList();
    _pending.removeWhere((p) => p.delay <= 0);
    for (final pending in due) {
      var category = pending.category;
      if (game.score.isCriticalRecovery) {
        category = DifficultyCategory.weak;
      }
      spawnSquad(category);
    }
  }

  void scheduleReplacement(DifficultyCategory category) {
    final delay = game.rng.range(
      SpawnConfig.replacementDelayMin,
      SpawnConfig.replacementDelayMax,
    );
    final next = game.score.isCriticalRecovery
        ? DifficultyCategory.weak
        : _categoryWithBiggestDeficit();
    _pending.add(_PendingReplacement(next, delay));
  }

  /// Keep the live mix close to the current slot plan as the player grows.
  DifficultyCategory _categoryWithBiggestDeficit() {
    final plan = SpawnConfig.slotPlan(game.score.maxScore);
    final counts = {
      for (final category in DifficultyCategory.values) category: 0,
    };
    for (final squad in game.squads.enemySquads.values) {
      if (!squad.eliminated) {
        counts[squad.category] = counts[squad.category]! + 1;
      }
    }
    for (final pending in _pending) {
      counts[pending.category] = counts[pending.category]! + 1;
    }
    var best = DifficultyCategory.weak;
    var bestDeficit = -1000;
    const priority = [
      DifficultyCategory.deadly,
      DifficultyCategory.strong,
      DifficultyCategory.normal,
      DifficultyCategory.weak,
    ];
    for (final category in priority) {
      final deficit = plan.of(category) - counts[category]!;
      if (deficit > bestDeficit) {
        bestDeficit = deficit;
        best = category;
      }
    }
    if (bestDeficit <= 0) {
      return DifficultyCategory.strong;
    }
    return best;
  }

  EnemySquad? spawnSquad(DifficultyCategory category) {
    final origin = _pickSpawnOrigin();
    if (origin == null) {
      scheduleReplacement(category);
      return null;
    }
    final clampedOrigin = WorldBounds.clamp(origin, SpawnConfig.spawnMapMargin);
    final composition = generateComposition(
      category,
      game.score.currentScore,
      game.score.maxScore,
      game.rng,
    );
    final patrolB = _pickPatrolPoint(clampedOrigin);
    final patrolType = game.rng.nextDouble() < SpawnConfig.pingPongChance
        ? PatrolType.pingPong
        : PatrolType.wander;
    final squad = EnemySquad(
      id: game.squads.allocateEnemyId(),
      category: category,
      archetype: composition.archetype,
      patrolType: patrolType,
      patrolA: clampedOrigin.clone(),
      patrolB: patrolB,
    );
    composition.counts.forEach((type, count) {
      for (var i = 0; i < count; i++) {
        final unit = UnitComponent(
          id: game.squads.allocateUnitId(),
          type: type,
          faction: Faction.enemy,
          subEnemyId: squad.id,
          startPosition: clampedOrigin.clone(),
          isMainSquad: false,
        );
        unit.rollProjectileStyle(game.rng);
        unit.aiState = UnitAiState.patrol;
        squad.members.add(unit);
        game.world.add(unit);
      }
    });
    squad.members.sort(
      (a, b) => b.physicalRadius.compareTo(a.physicalRadius),
    );
    final spacing = SquadSystem.packedSpacing(squad.members);
    for (var i = 0; i < squad.members.length; i++) {
      final unit = squad.members[i];
      final offset = _sunflower(i, spacing);
      unit.position.setFrom(
        WorldBounds.clamp(clampedOrigin + offset, unit.physicalRadius),
      );
    }
    squad.rebuildFormation(spacing);
    game.squads.enemySquads[squad.id] = squad;
    return squad;
  }

  /// Builds an enemy horde whose listed score sits in a threat band relative
  /// to the living army. Entry point for a full rewrite of this algorithm.
  static SquadComposition generateComposition(
    DifficultyCategory category,
    int currentScore,
    int maxScore,
    GameRng rng,
  ) {
    var budget = _budget(category, currentScore, maxScore, rng);
    budget *= rng.range(1 - SpawnConfig.budgetVariance, 1 + SpawnConfig.budgetVariance);
    budget = max(1, budget);
    final allowed = _allowedTypes(
      maxScore: maxScore,
      budget: budget,
      category: category,
      rng: rng,
    );
    var archetype = _pickArchetype(allowed, rng, category);
    if (category == DifficultyCategory.weak && currentScore <= 8) {
      archetype = SquadArchetype.swarm;
    }
    final counts = _fillCounts(
      archetype,
      budget,
      allowed,
      rng,
      category,
      currentScore,
    );
    if (counts.values.fold(0, (a, b) => a + b) == 0) {
      counts[UnitType.miniKnight] = 1;
    }
    var total = 0;
    counts.forEach((type, count) {
      total += UnitCatalog.stats(type).scoreValue * count;
    });
    return SquadComposition(
      category: category,
      archetype: archetype,
      counts: counts,
      totalScore: total,
    );
  }

  void _tickPatrols() {
    for (final squad in game.squads.enemySquads.values) {
      if (squad.eliminated || !squad.hasLivingMembers || squad.inCombat) {
        continue;
      }
      squad.currentPatrolTarget =
          WorldBounds.clamp(squad.currentPatrolTarget, 280);
      squad.patrolA.setFrom(WorldBounds.clamp(squad.patrolA, 280));
      squad.patrolB.setFrom(WorldBounds.clamp(squad.patrolB, 280));
      final center = squad.center;
      if (center.distanceTo(squad.currentPatrolTarget) > 46) {
        continue;
      }
      if (squad.patrolType == PatrolType.pingPong) {
        squad.headingToB = !squad.headingToB;
        squad.currentPatrolTarget =
            (squad.headingToB ? squad.patrolB : squad.patrolA).clone();
      } else {
        squad.patrolA.setFrom(squad.currentPatrolTarget);
        squad.currentPatrolTarget = _pickPatrolPoint(squad.currentPatrolTarget);
      }
    }
  }

  Vector2? _pickSpawnOrigin() {
    final team = game.squads.teamCenter;
    Rect? view;
    if (game.camera.isMounted) {
      view = game.camera.visibleWorldRect.inflate(48);
    }
    for (var i = 0; i < SpawnConfig.spawnLocationAttempts; i++) {
      final point = Vector2(
        SpawnConfig.spawnMapMargin +
            game.rng.nextDouble() *
                (GameConfig.worldWidth - SpawnConfig.spawnMapMargin * 2),
        SpawnConfig.spawnMapMargin +
            game.rng.nextDouble() *
                (GameConfig.worldHeight - SpawnConfig.spawnMapMargin * 2),
      );
      if (view != null && view.contains(Offset(point.x, point.y))) {
        continue;
      }
      if (point.distanceTo(team) < SpawnConfig.minimumSpawnDistanceFromPlayer) {
        continue;
      }
      return WorldBounds.clamp(point, SpawnConfig.spawnMapMargin);
    }
    final margin = SpawnConfig.spawnMapMargin;
    final corners = [
      Vector2(margin, margin),
      Vector2(GameConfig.worldWidth - margin, margin),
      Vector2(margin, GameConfig.worldHeight - margin),
      Vector2(GameConfig.worldWidth - margin, GameConfig.worldHeight - margin),
    ];
    corners.sort((a, b) => b.distanceToSquared(team).compareTo(a.distanceToSquared(team)));
    return corners.first;
  }

  Vector2 _pickPatrolPoint(Vector2 from) {
    for (var i = 0; i < 12; i++) {
      final angle = game.rng.range(0, pi * 2);
      final dist = game.rng.range(220, 520);
      final point = WorldBounds.clamp(
        from + Vector2(cos(angle) * dist, sin(angle) * dist),
        280,
      );
      if (point.distanceTo(from) > 140) {
        return point;
      }
    }
    return WorldBounds.clamp(from + Vector2(220, 0), 280);
  }

  Vector2 _sunflower(int index, double spacing) {
    const golden = 2.399963;
    final r = index == 0 ? 0.0 : spacing * sqrt(index + 0.4);
    final a = index * golden;
    return Vector2(cos(a) * r, sin(a) * r);
  }

  static double _budget(
    DifficultyCategory category,
    int currentScore,
    int maxScore,
    GameRng rng,
  ) {
    final current = max(1, currentScore);
    switch (category) {
      case DifficultyCategory.weak:
        if (currentScore <= 1) {
          return 1;
        }
        return current *
            rng.range(
              SpawnConfig.weakBudgetMinFactor,
              SpawnConfig.weakBudgetMaxFactor,
            );
      case DifficultyCategory.normal:
        return current *
            rng.range(
              SpawnConfig.evenBudgetMinFactor,
              SpawnConfig.evenBudgetMaxFactor,
            );
      case DifficultyCategory.strong:
        return current *
            rng.range(
              SpawnConfig.strongBudgetMinFactor,
              SpawnConfig.strongBudgetMaxFactor,
            );
      case DifficultyCategory.deadly:
        final deadly = current *
            rng.range(
              SpawnConfig.deadlyBudgetMinFactor,
              SpawnConfig.deadlyBudgetMaxFactor,
            );
        // After a deep run, keep at least some peak-relative pressure.
        final floor = maxScore * 0.12;
        return max(deadly, floor);
    }
  }

  /// Progress unlocks plus a budget cap so a deadly pack can field tanks
  /// the player has not "unlocked" yet, without dropping a Golem on a 20-score army.
  static Set<UnitType> _allowedTypes({
    required int maxScore,
    required double budget,
    required DifficultyCategory category,
    required GameRng rng,
  }) {
    final allowed = <UnitType>{UnitType.miniKnight};
    final budgetCap = switch (category) {
      DifficultyCategory.weak => budget * 0.35,
      DifficultyCategory.normal => budget * 0.40,
      DifficultyCategory.strong => budget * 0.55,
      DifficultyCategory.deadly => budget * 0.70,
    };
    SpawnConfig.unlocks.forEach((type, thresholds) {
      if (type == UnitType.miniKnight) {
        return;
      }
      final score = UnitCatalog.stats(type).scoreValue;
      final byProgress = maxScore >= thresholds.commonAt ||
          (maxScore >= thresholds.rareAt && rng.nextDouble() < 0.28);
      final byBudget = score <= budgetCap;
      if (byProgress || byBudget) {
        allowed.add(type);
      }
    });
    return allowed;
  }

  static SquadArchetype _pickArchetype(
    Set<UnitType> allowed,
    GameRng rng,
    DifficultyCategory category,
  ) {
    final items = <SquadArchetype>[];
    final weights = <double>[];
    void add(SquadArchetype archetype, double weight, UnitType? need) {
      if (need != null && !allowed.contains(need)) {
        return;
      }
      items.add(archetype);
      weights.add(weight);
    }

    switch (category) {
      case DifficultyCategory.weak:
        add(SquadArchetype.swarm, 1.4, null);
        add(SquadArchetype.knightLine, 0.7, UnitType.mediumKnight);
        add(SquadArchetype.mixed, 0.25, UnitType.mediumKnight);
      case DifficultyCategory.normal:
        add(SquadArchetype.mixed, 1.0, UnitType.mediumKnight);
        add(SquadArchetype.knightLine, 1.0, UnitType.mediumKnight);
        add(SquadArchetype.casterEscort, 0.9, UnitType.wizard);
        add(SquadArchetype.swarm, 0.7, null);
        add(SquadArchetype.rangedBall, 0.55, UnitType.wizard);
        add(SquadArchetype.heavyLine, 0.5, UnitType.heavyKnight);
      case DifficultyCategory.strong:
        add(SquadArchetype.heavyLine, 1.0, UnitType.heavyKnight);
        add(SquadArchetype.casterEscort, 0.95, UnitType.wizard);
        add(SquadArchetype.golemEscort, 0.9, UnitType.miniGolem);
        add(SquadArchetype.rangedBall, 0.8, UnitType.wizard);
        add(SquadArchetype.tankWall, 0.7, UnitType.miniGolem);
        add(SquadArchetype.mixed, 0.7, UnitType.mediumKnight);
        add(SquadArchetype.titan, 0.45, UnitType.golem);
      case DifficultyCategory.deadly:
        add(SquadArchetype.rangedBall, 0.62, UnitType.wizard);
        add(SquadArchetype.casterEscort, 0.9, UnitType.wizard);
        add(SquadArchetype.titan, 0.85, UnitType.golem);
        add(SquadArchetype.tankWall, 0.7, UnitType.miniGolem);
        add(SquadArchetype.golemEscort, 0.7, UnitType.miniGolem);
        add(SquadArchetype.heavyLine, 0.75, UnitType.heavyKnight);
        add(SquadArchetype.mixed, 0.8, UnitType.heavyKnight);
    }
    if (items.isEmpty) {
      return SquadArchetype.swarm;
    }
    return rng.pickWeighted(items, weights);
  }

  static Map<UnitType, int> _fillCounts(
    SquadArchetype archetype,
    double budget,
    Set<UnitType> allowed,
    GameRng rng,
    DifficultyCategory category,
    int currentScore,
  ) {
    if (category == DifficultyCategory.weak && budget <= 1.5) {
      return {UnitType.miniKnight: 1};
    }
    final rawRatios = Map<UnitType, double>.from(
      SpawnConfig.archetypeRatios[archetype]!,
    );
    rawRatios.removeWhere((type, _) => !allowed.contains(type));
    if (rawRatios.isEmpty) {
      return {UnitType.miniKnight: max(1, min(8, budget.round()))};
    }
    final ratioSum = rawRatios.values.fold(0.0, (a, b) => a + b);
    final ratios = {
      for (final e in rawRatios.entries) e.key: e.value / ratioSum,
    };
    var avg = 0.0;
    ratios.forEach((type, ratio) {
      avg += ratio * UnitCatalog.stats(type).scoreValue;
    });
    avg = max(1, avg);
    var minCount = SpawnConfig.minUnitCounts[archetype]!;
    final hardCap = SpawnConfig.unitCap(category, currentScore);
    var maxCount = hardCap;
    if (category == DifficultyCategory.weak) {
      minCount = 1;
      maxCount = min(12, maxCount);
    }
    // Spend the budget. Do not pull toward a flavor "preferred" size — that
    // used to cap a deadly pack at 14 heavies (~350 score) forever.
    var count = (budget / avg).round().clamp(minCount, maxCount);

    final counts = <UnitType, int>{};
    var assigned = 0;
    final types = ratios.keys.toList()
      ..sort((a, b) => ratios[b]!.compareTo(ratios[a]!));
    for (final type in types) {
      final n = max(0, (count * ratios[type]!).round());
      counts[type] = n;
      assigned += n;
    }
    if (assigned == 0) {
      counts[types.first] = max(1, minCount);
      assigned = counts[types.first]!;
    }
    while (assigned < count) {
      final type = rng.pick(types);
      counts[type] = (counts[type] ?? 0) + 1;
      assigned++;
    }
    while (assigned > count) {
      final bulky = types.firstWhere(
        (t) => (counts[t] ?? 0) > 0,
        orElse: () => types.first,
      );
      if ((counts[bulky] ?? 0) <= 0) {
        break;
      }
      counts[bulky] = counts[bulky]! - 1;
      assigned--;
    }

    var total = _scoreOf(counts);
    final low = budget * 0.92;
    final high = budget * 1.18;
    final expensive = _upgradeTarget(counts, allowed);
    var guard = 0;
    while (total < low && guard < 220) {
      if (assigned < maxCount) {
        counts[expensive] = (counts[expensive] ?? 0) + 1;
        assigned++;
      } else {
        final cheap = _cheapestPresent(counts);
        if (cheap == null || cheap == expensive) {
          if (assigned < hardCap) {
            maxCount = hardCap;
            continue;
          }
          break;
        }
        counts[cheap] = counts[cheap]! - 1;
        if (counts[cheap] == 0) {
          counts.remove(cheap);
        }
        counts[expensive] = (counts[expensive] ?? 0) + 1;
      }
      total = _scoreOf(counts);
      guard++;
    }
    guard = 0;
    while (total > high && assigned > minCount && guard < 40) {
      final type = _cheapestPresent(counts);
      if (type == null) {
        break;
      }
      counts[type] = counts[type]! - 1;
      if (counts[type] == 0) {
        counts.remove(type);
      }
      assigned--;
      total = _scoreOf(counts);
      guard++;
    }
    counts.removeWhere((_, value) => value <= 0);
    _diversifyGolemPacks(counts, allowed, rng, archetype);
    _clampAssigned(counts, hardCap);
    _capWizardShare(counts, allowed, rng, archetype);
    _clampAssigned(counts, hardCap);
    counts.removeWhere((_, value) => value <= 0);
    return counts;
  }

  static UnitType _upgradeTarget(
    Map<UnitType, int> counts,
    Set<UnitType> allowed,
  ) {
    final golems = counts[UnitType.golem] ?? 0;
    final miniG = counts[UnitType.miniGolem] ?? 0;
    if (golems >= 8 && allowed.contains(UnitType.heavyKnight)) {
      return UnitType.heavyKnight;
    }
    if (miniG >= 10 && allowed.contains(UnitType.heavyKnight)) {
      return UnitType.heavyKnight;
    }
    if (golems + miniG >= 12 && allowed.contains(UnitType.mediumKnight)) {
      return UnitType.mediumKnight;
    }
    return _priciestAllowed(allowed);
  }

  static void _diversifyGolemPacks(
    Map<UnitType, int> counts,
    Set<UnitType> allowed,
    GameRng rng,
    SquadArchetype archetype,
  ) {
    var golems = counts[UnitType.golem] ?? 0;
    var miniG = counts[UnitType.miniGolem] ?? 0;
    if (golems + miniG == 0) {
      return;
    }
    const maxGolem = 8;
    const maxMiniGolem = 10;
    while (golems > maxGolem) {
      golems--;
      counts[UnitType.golem] = golems;
      _convertTankBudget(counts, allowed, rng, 150);
    }
    while (miniG > maxMiniGolem) {
      miniG--;
      counts[UnitType.miniGolem] = miniG;
      _convertTankBudget(counts, allowed, rng, 60);
    }
    final total = counts.values.fold(0, (a, b) => a + b);
    final wizards = counts[UnitType.wizard] ?? 0;
    if (allowed.contains(UnitType.wizard) &&
        total >= 8 &&
        wizards < 2 &&
        archetype != SquadArchetype.swarm) {
      _addSupport(counts, allowed, rng, prefer: UnitType.wizard);
    }
    final melee = (counts[UnitType.miniKnight] ?? 0) +
        (counts[UnitType.mediumKnight] ?? 0) +
        (counts[UnitType.heavyKnight] ?? 0);
    if (melee < max(4, (total * 0.22).round()) &&
        allowed.contains(UnitType.miniKnight)) {
      counts[UnitType.miniKnight] =
          (counts[UnitType.miniKnight] ?? 0) +
              (max(4, (total * 0.22).round()) - melee);
    }
  }

  static void _convertTankBudget(
    Map<UnitType, int> counts,
    Set<UnitType> allowed,
    GameRng rng,
    int score,
  ) {
    var left = score;
    void add(UnitType type, int cost) {
      if (left < cost || !allowed.contains(type)) {
        return;
      }
      counts[type] = (counts[type] ?? 0) + 1;
      left -= cost;
    }

    while (left >= 25 && allowed.contains(UnitType.heavyKnight)) {
      add(UnitType.heavyKnight, 25);
    }
    if (rng.nextDouble() < 0.55) {
      add(UnitType.wizard, 18);
    }
    while (left >= 10 && allowed.contains(UnitType.mediumKnight)) {
      add(UnitType.mediumKnight, 10);
    }
    if (left > 0) {
      counts[UnitType.miniKnight] =
          (counts[UnitType.miniKnight] ?? 0) + min(left, 6);
    }
  }

  static void _clampAssigned(Map<UnitType, int> counts, int cap) {
    var assigned = counts.values.fold(0, (a, b) => a + b);
    var guard = 0;
    while (assigned > cap && guard < 400) {
      final cheap = _cheapestPresent(counts);
      if (cheap == null) {
        break;
      }
      counts[cheap] = counts[cheap]! - 1;
      if (counts[cheap] == 0) {
        counts.remove(cheap);
      }
      assigned--;
      guard++;
    }
  }

  static void _capWizardShare(
    Map<UnitType, int> counts,
    Set<UnitType> allowed,
    GameRng rng,
    SquadArchetype archetype,
  ) {
    var wizards = counts[UnitType.wizard] ?? 0;
    if (wizards == 0) {
      return;
    }
    final total = counts.values.fold(0, (a, b) => a + b);
    if (total == 0) {
      return;
    }
    final maxShare = archetype == SquadArchetype.rangedBall ? 0.48 : 0.34;
    var cap = max(3, (total * maxShare).round());
    if (archetype == SquadArchetype.rangedBall) {
      cap = max(cap, 8);
    }
    while (wizards > cap) {
      wizards--;
      counts[UnitType.wizard] = wizards;
      if (allowed.contains(UnitType.mediumKnight) && rng.nextDouble() < 0.45) {
        counts[UnitType.mediumKnight] = (counts[UnitType.mediumKnight] ?? 0) + 1;
      } else if (allowed.contains(UnitType.heavyKnight) &&
          rng.nextDouble() < 0.35) {
        counts[UnitType.heavyKnight] = (counts[UnitType.heavyKnight] ?? 0) + 1;
      } else {
        counts[UnitType.miniKnight] = (counts[UnitType.miniKnight] ?? 0) + 1;
      }
    }
  }

  static void _addSupport(
    Map<UnitType, int> counts,
    Set<UnitType> allowed,
    GameRng rng, {
    UnitType? prefer,
  }) {
    if (prefer != null && allowed.contains(prefer)) {
      counts[prefer] = (counts[prefer] ?? 0) + 1;
      return;
    }
    const ladder = [
      UnitType.wizard,
      UnitType.miniKnight,
      UnitType.mediumKnight,
      UnitType.heavyKnight,
    ];
    if (rng.nextDouble() < 0.4 && allowed.contains(UnitType.miniKnight)) {
      counts[UnitType.miniKnight] = (counts[UnitType.miniKnight] ?? 0) + 3;
      return;
    }
    for (final type in ladder) {
      if (allowed.contains(type)) {
        counts[type] = (counts[type] ?? 0) + (type == UnitType.miniKnight ? 3 : 1);
        return;
      }
    }
    counts[UnitType.miniKnight] = (counts[UnitType.miniKnight] ?? 0) + 2;
  }

  static int _scoreOf(Map<UnitType, int> counts) {
    var total = 0;
    counts.forEach((type, count) {
      total += UnitCatalog.stats(type).scoreValue * count;
    });
    return total;
  }

  static UnitType _priciestAllowed(Set<UnitType> allowed) {
    UnitType best = UnitType.miniKnight;
    var bestScore = -1;
    var bestThreat = -1.0;
    for (final type in allowed) {
      final score = UnitCatalog.stats(type).scoreValue;
      final threat = UnitCatalog.combatThreat(type);
      if (score > bestScore || (score == bestScore && threat > bestThreat)) {
        bestScore = score;
        bestThreat = threat;
        best = type;
      }
    }
    return best;
  }

  static UnitType? _cheapestPresent(Map<UnitType, int> counts) {
    UnitType? best;
    var bestScore = 1 << 30;
    counts.forEach((type, count) {
      if (count <= 0) {
        return;
      }
      final score = UnitCatalog.stats(type).scoreValue;
      if (score < bestScore) {
        bestScore = score;
        best = type;
      }
    });
    return best;
  }
}
