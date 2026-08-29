import 'dart:math';

import 'package:flame/components.dart';

import '../components/units/unit_component.dart';
import '../config/game_config.dart';
import '../models/enemy_squad.dart';
import '../models/faction.dart';
import 'spatial_grid.dart';

class SquadSystem {
  final Vector2 teamCenter = Vector2.zero();
  double teamRadius = 48;
  Vector2? moveDestination;
  Vector2? moveDirection;
  bool hasMoveOrder = false;
  bool commitDisengage = false;
  int moveOrderSerial = 0;
  int? focusHuntSquadId;

  final Map<int, EnemySquad> enemySquads = {};
  int nextEnemyId = 1;
  int nextUnitId = 1;
  final Map<int, Vector2> friendlyFormation = {};

  int allocateUnitId() => nextUnitId++;

  int allocateEnemyId() => nextEnemyId++;

  List<UnitComponent> cachedMainFriendlies = [];

  void reset() {
    teamCenter.setZero();
    teamRadius = 48;
    clearMoveOrder();
    focusHuntSquadId = null;
    cachedMainFriendlies = [];
    enemySquads.clear();
    nextEnemyId = 1;
    nextUnitId = 1;
    friendlyFormation.clear();
  }

  void clearMoveOrder() {
    moveDestination = null;
    moveDirection = null;
    hasMoveOrder = false;
    commitDisengage = false;
    moveOrderSerial = 0;
  }

  void clearFocusHunt() {
    focusHuntSquadId = null;
  }

  void beginFocusHunt(int squadId) {
    focusHuntSquadId = squadId;
    moveDestination = null;
    moveDirection = null;
    hasMoveOrder = false;
    commitDisengage = false;
    moveOrderSerial++;
  }

  void setJoystickOrder(Vector2 direction, double intensity) {
    if (intensity >= GameConfig.joystickCommitThreshold) {
      clearFocusHunt();
    }
    moveDirection = direction.normalized();
    moveDestination = null;
    hasMoveOrder = true;
    commitDisengage = intensity >= GameConfig.joystickCommitThreshold;
  }

  void setClickOrder(Vector2 destination) {
    clearFocusHunt();
    moveDestination = destination.clone();
    moveDirection = null;
    hasMoveOrder = true;
    commitDisengage = true;
  }

  void recompute(List<UnitComponent> units) {
    final main = <UnitComponent>[];
    for (final unit in units) {
      if (unit.isAlive && unit.isFriendly && unit.isMainSquad) {
        main.add(unit);
      }
    }
    if (main.isEmpty) {
      cachedMainFriendlies = [];
      final living = [
        for (final unit in units)
          if (unit.isAlive && unit.isFriendly) unit,
      ];
      if (living.isEmpty) {
        return;
      }
      _averageInto(teamCenter, living);
      teamRadius = 60;
      return;
    }
    _averageInto(teamCenter, main);
    final dists = [
      for (final unit in main) unit.position.distanceTo(teamCenter),
    ]..sort();
    final edge = dists[(dists.length * 0.86).floor().clamp(0, dists.length - 1)];
    teamRadius = max(
      36,
      edge * GameConfig.teamRadiusPaddingFactor + GameConfig.cohesionMargin,
    );
    _rebuildFriendlyFormation(main);
    cachedMainFriendlies = main;

    for (final squad in enemySquads.values) {
      if (squad.eliminated) {
        continue;
      }
      final living = [for (final m in squad.members) if (m.isAlive) m];
      if (living.isNotEmpty) {
        squad.rebuildFormation(packedSpacing(living));
        squad.inCombat = living.any((m) => m.isFighting);
      } else {
        squad.inCombat = false;
      }
    }

    if (hasMoveOrder && moveDestination != null) {
      if (teamCenter.distanceTo(moveDestination!) <=
          GameConfig.orderArriveDistance) {
        clearMoveOrder();
      }
    }
    final huntId = focusHuntSquadId;
    if (huntId != null) {
      final hunted = enemySquads[huntId];
      if (hunted == null || hunted.eliminated || !hunted.hasLivingMembers) {
        focusHuntSquadId = null;
      }
    }
  }

  bool isInsideMainArmy(Vector2 position) {
    return position.distanceTo(teamCenter) <= teamRadius + GameConfig.joinMargin;
  }

  List<UnitComponent> assistanceGroup(UnitComponent unit) {
    if (unit.isFriendly) {
      if (!unit.isMainSquad) {
        return const [];
      }
      return cachedMainFriendlies;
    }
    final id = unit.subEnemyId;
    if (id == null) {
      return const [];
    }
    final squad = enemySquads[id];
    if (squad == null) {
      return const [];
    }
    return [
      for (final member in squad.members)
        if (member.isAlive) member,
    ];
  }

  EnemySquad? squadOf(UnitComponent unit) {
    final id = unit.subEnemyId;
    if (id == null) {
      return null;
    }
    return enemySquads[id];
  }

  Vector2 formationSlotFor(UnitComponent unit) {
    if (unit.isFriendly) {
      final offset = friendlyFormation[unit.id] ?? Vector2.zero();
      if (moveDestination != null) {
        return moveDestination! + offset;
      }
      return teamCenter + offset;
    }
    final squad = squadOf(unit);
    if (squad == null) {
      return unit.position.clone();
    }
    final offset = squad.formationOffsets[unit.id] ?? Vector2.zero();
    if (squad.inCombat) {
      return squad.center + offset;
    }
    return squad.currentPatrolTarget + offset;
  }

  UnitComponent? findById(List<UnitComponent> units, int? id) {
    if (id == null) {
      return null;
    }
    for (final unit in units) {
      if (unit.id == id && unit.isAlive) {
        return unit;
      }
    }
    return null;
  }

  bool chaseExceeded(UnitComponent unit) {
    if (unit.isFriendly &&
        focusHuntSquadId != null &&
        unit.isMainSquad) {
      return false;
    }
    final origin = unit.isFriendly
        ? teamCenter
        : (squadOf(unit)?.center ?? unit.chaseStartPosition);
    if (origin == null) {
      return false;
    }
    final leash = unit.maxChaseDistance *
        (unit.assistMateId != null ? 1.7 : 1.0);
    return unit.position.distanceTo(origin) > leash;
  }

  List<UnitComponent> huntedHostiles() {
    final id = focusHuntSquadId;
    if (id == null) {
      return const [];
    }
    final squad = enemySquads[id];
    if (squad == null || squad.eliminated) {
      return const [];
    }
    return [for (final m in squad.members) if (m.isAlive) m];
  }

  void markChaseStart(UnitComponent unit) {
    unit.chaseStartPosition ??= unit.position.clone();
  }

  List<UnitComponent> hostilesInSight(
    UnitComponent unit,
    SpatialGrid grid,
  ) {
    final nearby = grid.queryRadius(unit.position, unit.effectiveSight);
    return [
      for (final other in nearby)
        if (other.isAlive && other.faction.isHostileTo(unit.faction)) other,
    ];
  }

  static double packedSpacing(List<UnitComponent> units) {
    if (units.isEmpty) {
      return GameConfig.formationSpacing;
    }
    var sum = 0.0;
    for (final unit in units) {
      sum += unit.physicalRadius;
    }
    final avg = sum / units.length;
    final n = units.length;
    // Large blobs stay tight, but not so tight that overlap-resolve explodes them.
    final pack = 1.0 - 0.22 * ((n - 8) / 180).clamp(0.0, 1.0);
    return (avg * 2.08 + 3.0) * pack;
  }

  void _rebuildFriendlyFormation(List<UnitComponent> main) {
    friendlyFormation.clear();
    const golden = 2.399963;
    final spacing = packedSpacing(main);
    final ordered = [...main]
      ..sort((a, b) => b.physicalRadius.compareTo(a.physicalRadius));
    for (var i = 0; i < ordered.length; i++) {
      final r = i == 0 ? 0.0 : spacing * sqrt(i + 0.18);
      final a = i * golden;
      friendlyFormation[ordered[i].id] = Vector2(cos(a) * r, sin(a) * r);
    }
  }

  void _averageInto(Vector2 out, List<UnitComponent> units) {
    var x = 0.0;
    var y = 0.0;
    for (final unit in units) {
      x += unit.position.x;
      y += unit.position.y;
    }
    out.setValues(x / units.length, y / units.length);
  }
}
