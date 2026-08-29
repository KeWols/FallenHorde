import 'dart:math';

import 'package:flame/components.dart';

import '../components/units/unit_component.dart';
import '../config/game_config.dart';
import '../models/faction.dart';
import '../necromancy_game.dart';

class TargetingSystem {
  TargetingSystem(this.game);

  final NecromancyGame game;

  UnitComponent? evaluate(UnitComponent unit) {
    if (unit.targetEvalTimer > 0) {
      final existing =
          game.squads.findById(game.world.units, unit.currentTargetId);
      final huntId = game.squads.focusHuntSquadId;
      final huntOk = huntId == null || existing?.subEnemyId == huntId;
      if (existing != null && huntOk && _stillValid(unit, existing)) {
        return existing;
      }
    }
    unit.targetEvalTimer =
        GameConfig.targetEvalInterval + (unit.id % 7) * 0.03;

    if (unit.isFriendly && unit.isMainSquad && game.squads.focusHuntSquadId != null) {
      final hunted = game.squads.huntedHostiles();
      final bestHunt = _pickBest(unit, hunted, requireReachable: !unit.isRanged);
      if (bestHunt != null) {
        unit.currentTargetId = bestHunt.id;
        unit.assistMateId = null;
        return bestHunt;
      }
    }

    final personal = _personalHostiles(unit);
    final bestPersonal = _pickBest(unit, personal);
    if (bestPersonal != null) {
      _maybeSwitch(unit, bestPersonal);
      unit.assistMateId = null;
      return game.squads.findById(game.world.units, unit.currentTargetId);
    }

    if (unit.isRanged) {
      final shared = _sharedHostilesInRange(unit);
      final bestShared = _pickBest(unit, shared, requireReachable: false);
      if (bestShared != null) {
        _maybeSwitch(unit, bestShared);
        unit.assistMateId = null;
        return game.squads.findById(game.world.units, unit.currentTargetId);
      }
    }

    if (unit.chaseAbortCooldown > 0) {
      unit.currentTargetId = null;
      unit.assistMateId = null;
      return null;
    }

    final mate = _nearestFightingTeammate(unit);
    if (mate != null) {
      unit.assistMateId = mate.id;
      unit.currentTargetId = mate.currentTargetId;
      return game.squads.findById(game.world.units, unit.currentTargetId);
    }

    unit.currentTargetId = null;
    unit.assistMateId = null;
    return null;
  }

  bool inAttackRange(UnitComponent attacker, UnitComponent target) {
    final dist = attacker.position.distanceTo(target.position);
    if (attacker.isRanged) {
      return dist <= attacker.stats.attackRadius;
    }
    // Edge-to-edge reach so collision separation cannot push melee out of range.
    return dist <=
        attacker.physicalRadius +
            target.physicalRadius +
            attacker.stats.attackRadius;
  }

  bool hasMeleeSlot(UnitComponent attacker, UnitComponent target) {
    if (attacker.isRanged) {
      return true;
    }
    if (inAttackRange(attacker, target)) {
      return true;
    }
    const slots = 12;
    final ring = attacker.physicalRadius + target.physicalRadius + 8;
    for (var i = 0; i < slots; i++) {
      final a = (2 * pi * i) / slots;
      final slot = target.position + Vector2(cos(a) * ring, sin(a) * ring);
      if (!WorldBounds.contains(slot)) {
        continue;
      }
      final blockers = game.spatial.queryRadius(slot, attacker.physicalRadius * 0.85);
      final blocked = blockers.any(
        (other) => other != attacker && other != target && other.isAlive,
      );
      if (!blocked) {
        return true;
      }
    }
    return false;
  }

  bool _stillValid(UnitComponent unit, UnitComponent target) {
    if (!target.isAlive || !target.faction.isHostileTo(unit.faction)) {
      return false;
    }
    if (unit.isFriendly &&
        game.squads.focusHuntSquadId != null &&
        target.subEnemyId == game.squads.focusHuntSquadId) {
      return true;
    }
    final dist = unit.position.distanceTo(target.position);
    if (unit.assistMateId != null) {
      final mate = game.squads.findById(game.world.units, unit.assistMateId);
      if (mate != null && mate.isAlive) {
        return dist <= unit.maxChaseDistance ||
            unit.position.distanceTo(mate.position) <=
                GameConfig.assistJoinRadius;
      }
    }
    if (unit.isRanged) {
      return inAttackRange(unit, target) || dist <= unit.effectiveSight * 1.35;
    }
    return dist <= unit.effectiveSight * 1.35;
  }

  List<UnitComponent> _personalHostiles(UnitComponent unit) {
    return game.squads.hostilesInSight(unit, game.spatial);
  }

  List<UnitComponent> _sharedHostilesInRange(UnitComponent unit) {
    final group = game.squads.assistanceGroup(unit);
    final seen = <int, UnitComponent>{};
    for (final mate in group) {
      for (final hostile in game.squads.hostilesInSight(mate, game.spatial)) {
        if (unit.position.distanceTo(hostile.position) <=
            unit.stats.attackRadius) {
          seen[hostile.id] = hostile;
        }
      }
    }
    return seen.values.toList();
  }

  UnitComponent? _pickBest(
    UnitComponent unit,
    List<UnitComponent> hostiles, {
    bool requireReachable = true,
  }) {
    UnitComponent? best;
    var bestDist = double.infinity;
    for (final hostile in hostiles) {
      if (requireReachable && !unit.isRanged && !hasMeleeSlot(unit, hostile)) {
        continue;
      }
      final dist = unit.position.distanceToSquared(hostile.position);
      if (dist < bestDist) {
        bestDist = dist;
        best = hostile;
      }
    }
    if (best == null && requireReachable) {
      return _pickBest(unit, hostiles, requireReachable: false);
    }
    return best;
  }

  void _maybeSwitch(UnitComponent unit, UnitComponent candidate) {
    final current = game.squads.findById(game.world.units, unit.currentTargetId);
    if (current == null || !current.isAlive) {
      unit.currentTargetId = candidate.id;
      return;
    }
    final currentDist = unit.position.distanceTo(current.position);
    final nextDist = unit.position.distanceTo(candidate.position);
    if (nextDist < currentDist * GameConfig.targetSwitchHysteresis) {
      unit.currentTargetId = candidate.id;
    }
  }

  UnitComponent? _nearestFightingTeammate(UnitComponent unit) {
    if (!unit.broadcastsAssistance) {
      return null;
    }
    final group = game.squads.assistanceGroup(unit);
    UnitComponent? best;
    var bestDist = double.infinity;
    for (final mate in group) {
      if (mate == unit || !mate.isFighting) {
        continue;
      }
      final dist = unit.position.distanceToSquared(mate.position);
      final join = max(
        GameConfig.assistJoinRadius,
        game.squads.teamRadius * 2.5,
      );
      if (dist > join * join) {
        continue;
      }
      if (dist < bestDist) {
        bestDist = dist;
        best = mate;
      }
    }
    return best;
  }
}
