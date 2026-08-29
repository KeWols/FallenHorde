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

  test('high maxScore does not explode into thousands of minis', () {
    final composition = SpawnSystem.generateComposition(
      DifficultyCategory.deadly,
      400,
      5000,
      GameRng(11),
    );
    expect(composition.totalUnits, lessThan(40));
    expect(composition.counts[UnitType.miniKnight] ?? 0, lessThan(composition.totalUnits));
    expect(
      composition.counts.keys.any(
        (type) =>
            type == UnitType.heavyKnight ||
            type == UnitType.miniGolem ||
            type == UnitType.golem ||
            type == UnitType.wizard,
      ),
      isTrue,
    );
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
