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

class _PendingReplacement {
  _PendingReplacement(this.category, this.delay);
  final DifficultyCategory category;
  double delay;
}

class SpawnSystem {
  SpawnSystem(this.game);

  final NecromancyGame game;
  final List<_PendingReplacement> _pending = [];

  void reset() {
    _pending.clear();
  }

  void populateInitial() {
    for (final category in DifficultyCategory.values) {
      final slots = SpawnConfig.slotsFor(category);
      for (var i = 0; i < slots; i++) {
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
    _pending.add(_PendingReplacement(category, delay));
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
    var index = 0;
    composition.counts.forEach((type, count) {
      for (var i = 0; i < count; i++) {
        final offset = _sunflower(index, GameConfig.formationSpacing);
        final radius = UnitCatalog.stats(type).physicalRadius;
        final unit = UnitComponent(
          id: game.squads.allocateUnitId(),
          type: type,
          faction: Faction.enemy,
          subEnemyId: squad.id,
          startPosition: WorldBounds.clamp(clampedOrigin + offset, radius),
          isMainSquad: false,
        );
        unit.aiState = UnitAiState.patrol;
        squad.members.add(unit);
        game.world.add(unit);
        index++;
      }
    });
    squad.rebuildFormation(GameConfig.formationSpacing);
    game.squads.enemySquads[squad.id] = squad;
    return squad;
  }

  static SquadComposition generateComposition(
    DifficultyCategory category,
    int currentScore,
    int maxScore,
    GameRng rng,
  ) {
    var budget = _budget(category, currentScore, maxScore, rng);
    budget *= rng.range(1 - SpawnConfig.budgetVariance, 1 + SpawnConfig.budgetVariance);
    budget = max(1, budget);
    final allowed = _allowedTypes(maxScore, rng);
    var archetype = _pickArchetype(allowed, rng);
    if (category == DifficultyCategory.weak && currentScore <= 8) {
      archetype = SquadArchetype.swarm;
    }
    final counts = _fillCounts(archetype, budget, allowed, rng, category);
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
        20,
      );
      if (point.distanceTo(from) > 140) {
        return point;
      }
    }
    return WorldBounds.clamp(from + Vector2(220, 0), 20);
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
    switch (category) {
      case DifficultyCategory.weak:
        if (currentScore <= 1) {
          return 1;
        }
        return currentScore *
            rng.range(SpawnConfig.weakBudgetMinFactor, SpawnConfig.weakBudgetMaxFactor);
      case DifficultyCategory.normal:
        return 7 + 0.62 * pow(max(5, maxScore), 0.68);
      case DifficultyCategory.strong:
        return 12 + 0.95 * pow(max(5, maxScore), 0.68);
      case DifficultyCategory.deadly:
        return 18 + 1.35 * pow(max(5, maxScore), 0.68);
    }
  }

  static Set<UnitType> _allowedTypes(int maxScore, GameRng rng) {
    final allowed = <UnitType>{UnitType.miniKnight};
    SpawnConfig.unlocks.forEach((type, thresholds) {
      if (type == UnitType.miniKnight) {
        return;
      }
      if (maxScore >= thresholds.commonAt) {
        allowed.add(type);
      } else if (maxScore >= thresholds.rareAt && rng.nextDouble() < 0.28) {
        allowed.add(type);
      }
    });
    return allowed;
  }

  static SquadArchetype _pickArchetype(Set<UnitType> allowed, GameRng rng) {
    final items = <SquadArchetype>[];
    final weights = <double>[];
    void add(SquadArchetype archetype, double weight, UnitType? need) {
      if (need != null && !allowed.contains(need)) {
        return;
      }
      items.add(archetype);
      weights.add(weight);
    }

    add(SquadArchetype.swarm, 1.1, null);
    add(SquadArchetype.knightLine, 1.0, UnitType.mediumKnight);
    add(SquadArchetype.casterEscort, 0.85, UnitType.wizard);
    add(SquadArchetype.heavyLine, 0.8, UnitType.heavyKnight);
    add(SquadArchetype.golemEscort, 0.7, UnitType.miniGolem);
    add(SquadArchetype.titan, 0.45, UnitType.golem);
    add(SquadArchetype.mixed, 0.75, UnitType.mediumKnight);
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
    var maxCount = SpawnConfig.maxUnitCounts[archetype]!;
    final preferred = SpawnConfig.preferredUnitCounts[archetype]!;
    if (category == DifficultyCategory.weak) {
      minCount = 1;
      maxCount = min(12, maxCount);
    }
    var count = (budget / avg).round();
    count = count.clamp(minCount, maxCount);
    count = ((count + preferred) / 2).round().clamp(minCount, maxCount);

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
    final low = budget * (1 - SpawnConfig.budgetVariance);
    final high = budget * (1 + SpawnConfig.budgetVariance);
    var guard = 0;
    while (total < low && assigned < maxCount && guard < 24) {
      final type = _upgradeOrAdd(counts, types, allowed);
      counts[type] = (counts[type] ?? 0) + 1;
      assigned++;
      total = _scoreOf(counts);
      guard++;
    }
    guard = 0;
    while (total > high && assigned > minCount && guard < 24) {
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
    return counts;
  }

  static int _scoreOf(Map<UnitType, int> counts) {
    var total = 0;
    counts.forEach((type, count) {
      total += UnitCatalog.stats(type).scoreValue * count;
    });
    return total;
  }

  static UnitType _upgradeOrAdd(
    Map<UnitType, int> counts,
    List<UnitType> types,
    Set<UnitType> allowed,
  ) {
    const ladder = [
      UnitType.golem,
      UnitType.miniGolem,
      UnitType.heavyKnight,
      UnitType.wizard,
      UnitType.mediumKnight,
      UnitType.miniKnight,
    ];
    for (final type in ladder) {
      if (allowed.contains(type) && types.contains(type)) {
        return type;
      }
    }
    return UnitType.miniKnight;
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
