import 'package:fallen_horde/game/models/difficulty.dart';
import 'package:fallen_horde/game/models/unit_type.dart';
import 'package:fallen_horde/game/services/game_rng.dart';
import 'package:fallen_horde/game/systems/spawn_system.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('weak recovery squad is a single mini knight', () {
    final composition = SpawnSystem.generateComposition(
      DifficultyCategory.weak,
      1,
      9892,
      GameRng(7),
    );
    expect(composition.counts[UnitType.miniKnight], 1);
    expect(composition.totalUnits, 1);
    expect(composition.totalScore, 1);
  });

  test('early weak squads stay below current score and use minis', () {
    final composition = SpawnSystem.generateComposition(
      DifficultyCategory.weak,
      5,
      5,
      GameRng(3),
    );
    expect(composition.totalScore, lessThan(5));
    expect(composition.counts.keys, [UnitType.miniKnight]);
  });

  test('even squads sit near current army power', () {
    final composition = SpawnSystem.generateComposition(
      DifficultyCategory.normal,
      100,
      100,
      GameRng(4),
    );
    expect(composition.totalScore, inInclusiveRange(70, 140));
  });

  test('strong squads outscale the current army', () {
    final composition = SpawnSystem.generateComposition(
      DifficultyCategory.strong,
      100,
      100,
      GameRng(9),
    );
    expect(composition.totalScore, greaterThan(120));
  });

  test('deadly squads are a serious threat, not a mini swarm', () {
    for (final seed in [11, 21, 33, 44, 55]) {
      final composition = SpawnSystem.generateComposition(
        DifficultyCategory.deadly,
        400,
        5000,
        GameRng(seed),
      );
      expect(composition.totalScore, greaterThan(700), reason: 'seed $seed');
      expect(composition.totalUnits, lessThan(90), reason: 'seed $seed');
      expect(
        composition.counts.keys.any(
          (type) =>
              type == UnitType.heavyKnight ||
              type == UnitType.miniGolem ||
              type == UnitType.golem ||
              type == UnitType.wizard,
        ),
        isTrue,
        reason: 'seed $seed',
      );
    }
  });

  test('deadly pressure exists before peak unlocks', () {
    final composition = SpawnSystem.generateComposition(
      DifficultyCategory.deadly,
      120,
      120,
      GameRng(8),
    );
    expect(composition.totalScore, greaterThan(200));
    expect(composition.totalScore, lessThan(500));
  });

  test('weak packs stay a farm even after the army snowballs', () {
    final composition = SpawnSystem.generateComposition(
      DifficultyCategory.weak,
      400,
      400,
      GameRng(2),
    );
    expect(composition.totalScore, lessThan(220));
  });

  test('golem-era packs keep wizards and chaff instead of a tank blob', () {
    var sawTanks = false;
    for (final seed in [3, 8, 15, 22, 41]) {
      final composition = SpawnSystem.generateComposition(
        DifficultyCategory.deadly,
        900,
        5000,
        GameRng(seed),
      );
      final tanks = (composition.counts[UnitType.golem] ?? 0) +
          (composition.counts[UnitType.miniGolem] ?? 0);
      if (tanks == 0) {
        continue;
      }
      sawTanks = true;
      expect(tanks, lessThan(20), reason: 'seed $seed');
      final total = composition.totalUnits;
      final wizards = composition.counts[UnitType.wizard] ?? 0;
      if (total > 0) {
        expect(wizards / total, lessThan(0.55), reason: 'seed $seed');
      }
      expect(
        (composition.counts[UnitType.wizard] ?? 0) +
            (composition.counts[UnitType.miniKnight] ?? 0),
        greaterThan(0),
        reason: 'seed $seed',
      );
    }
    expect(sawTanks, isTrue);
  });

  test('late deadly packs stay mixed instead of 10 golems plus a wizard blob', () {
    for (final seed in [5, 12, 19, 27, 40]) {
      final composition = SpawnSystem.generateComposition(
        DifficultyCategory.deadly,
        2200,
        5000,
        GameRng(seed),
      );
      final total = composition.totalUnits;
      final wizards = composition.counts[UnitType.wizard] ?? 0;
      expect(total, greaterThan(55), reason: 'seed $seed');
      expect(total, lessThan(181), reason: 'seed $seed');
      if (total > 0) {
        expect(wizards / total, lessThan(0.5), reason: 'seed $seed');
      }
    }
  });

  test('late deadly packs can exceed the old 55-unit cap', () {
    final composition = SpawnSystem.generateComposition(
      DifficultyCategory.deadly,
      2200,
      5000,
      GameRng(19),
    );
    expect(composition.totalUnits, greaterThan(55));
    expect(composition.totalUnits, lessThan(181));
  });

  test('seeded generation is deterministic', () {
    final a = SpawnSystem.generateComposition(
      DifficultyCategory.normal,
      80,
      80,
      GameRng(42),
    );
    final b = SpawnSystem.generateComposition(
      DifficultyCategory.normal,
      80,
      80,
      GameRng(42),
    );
    expect(a.counts, b.counts);
    expect(a.archetype, b.archetype);
  });
}
