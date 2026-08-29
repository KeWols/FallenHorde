import 'dart:math';

import 'package:flame/components.dart';

import '../components/graves/grave_component.dart';
import '../components/units/unit_component.dart';
import 'difficulty.dart';
import 'patrol_type.dart';
import 'squad_archetype.dart';
import 'unit_type.dart';

class EnemySquad {
  EnemySquad({
    required this.id,
    required this.category,
    required this.archetype,
    required this.patrolType,
    required this.patrolA,
    required this.patrolB,
  }) : currentPatrolTarget = patrolB.clone();

  final int id;
  final DifficultyCategory category;
  final SquadArchetype archetype;
  final PatrolType patrolType;
  final Vector2 patrolA;
  final Vector2 patrolB;
  Vector2 currentPatrolTarget;
  bool headingToB = true;
  bool inCombat = false;
  bool eliminated = false;

  final List<UnitComponent> members = [];
  final List<GraveComponent> graves = [];
  final Map<int, Vector2> formationOffsets = {};

  Vector2 get center {
    final living = [for (final m in members) if (m.isAlive) m];
    if (living.isEmpty) {
      return patrolA.clone();
    }
    var x = 0.0;
    var y = 0.0;
    for (final m in living) {
      x += m.position.x;
      y += m.position.y;
    }
    return Vector2(x / living.length, y / living.length);
  }

  bool get hasLivingMembers => members.any((m) => m.isAlive);

  void rebuildFormation(double spacing) {
    formationOffsets.clear();
    const golden = 2.399963;
    for (var i = 0; i < members.length; i++) {
      final r = i == 0 ? 0.0 : spacing * sqrt(i + 0.4);
      final a = i * golden;
      formationOffsets[members[i].id] = Vector2(cos(a) * r, sin(a) * r);
    }
  }
}

class SquadComposition {
  const SquadComposition({
    required this.category,
    required this.archetype,
    required this.counts,
    required this.totalScore,
  });

  final DifficultyCategory category;
  final SquadArchetype archetype;
  final Map<UnitType, int> counts;
  final int totalScore;

  int get totalUnits => counts.values.fold(0, (sum, count) => sum + count);
}
