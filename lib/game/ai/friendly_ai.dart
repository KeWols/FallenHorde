import 'dart:math';

import 'package:flame/components.dart';

import '../components/units/unit_component.dart';
import '../config/game_config.dart';
import '../models/ai_state.dart';
import '../necromancy_game.dart';
import 'wizard_ai.dart';

class FriendlyAi {
  static void step(NecromancyGame game, UnitComponent unit) {
    _acknowledgeOrder(game, unit);
    _updateMembership(game, unit);

    if (unit.regroupTimer > 0 && game.squads.focusHuntSquadId == null) {
      _regroup(game, unit);
      return;
    }

    if (!unit.isMainSquad) {
      _isolatedOrRejoin(game, unit);
      return;
    }

    if (_shouldFollowOrder(game, unit) &&
        !_shouldPeelForFight(game, unit)) {
      final opportunity = _hostileInMelee(game, unit);
      if (opportunity != null) {
        game.combat.tryAttack(unit, opportunity);
      }
      _followOrder(game, unit);
      return;
    }

    final target = game.targeting.evaluate(unit);
    if (target != null) {
      _engage(game, unit, target);
      return;
    }
    if (unit.assistMateId != null) {
      final mate = game.squads.findById(game.world.units, unit.assistMateId);
      if (mate != null) {
        unit.aiState = UnitAiState.assistTeammate;
        unit.desiredVelocity.setFrom(mate.position - unit.position);
        return;
      }
    }

    unit.aiState = game.squads.hasMoveOrder
        ? UnitAiState.followPlayerOrder
        : UnitAiState.idleWithTeam;
    _cohese(game, unit);
  }

  static void _acknowledgeOrder(NecromancyGame game, UnitComponent unit) {
    if (!game.squads.hasMoveOrder) {
      return;
    }
    if (unit.seenOrderSerial == game.squads.moveOrderSerial) {
      return;
    }
    unit.seenOrderSerial = game.squads.moveOrderSerial;
    if (game.squads.commitDisengage && unit.isFighting) {
      unit.disengageTimer = game.rng.range(
        GameConfig.disengageMin,
        GameConfig.disengageMax,
      );
    } else {
      unit.disengageTimer = 0;
    }
  }

  static bool _shouldPeelForFight(NecromancyGame game, UnitComponent unit) {
    if (game.squads.focusHuntSquadId != null) {
      return true;
    }
    if (unit.regroupTimer > 0) {
      return false;
    }
    if (game.squads.commitDisengage && game.squads.hasMoveOrder) {
      return false;
    }
    if (game.squads.hostilesInSight(unit, game.spatial).isNotEmpty) {
      return true;
    }
    final group = game.squads.cachedMainFriendlies;
    for (final mate in group) {
      if (mate == unit || !mate.isFighting) {
        continue;
      }
      if (unit.position.distanceTo(mate.position) <= GameConfig.assistJoinRadius) {
        return true;
      }
    }
    return false;
  }

  static bool _shouldFollowOrder(NecromancyGame game, UnitComponent unit) {
    if (!game.squads.hasMoveOrder) {
      return false;
    }
    if (!game.squads.commitDisengage) {
      return !unit.isFighting;
    }
    if (unit.committedAttackTimer > 0) {
      return false;
    }
    if (unit.disengageTimer > 0) {
      return false;
    }
    return true;
  }

  static void _followOrder(NecromancyGame game, UnitComponent unit) {
    unit.aiState = UnitAiState.followPlayerOrder;
    if (game.squads.moveDirection != null) {
      unit.desiredVelocity.setFrom(game.squads.moveDirection!);
      final toCenter = game.squads.teamCenter - unit.position;
      if (toCenter.length > game.squads.teamRadius * 0.55) {
        unit.desiredVelocity.add(toCenter.normalized() * GameConfig.cohesionWeight);
      }
      return;
    }
    final slot = game.squads.formationSlotFor(unit);
    unit.desiredVelocity.setFrom(slot - unit.position);
  }

  static void _regroup(NecromancyGame game, UnitComponent unit) {
    final melee = _hostileInMelee(game, unit);
    if (melee != null) {
      game.combat.tryAttack(unit, melee);
    }
    unit.clearTarget();
    if (!unit.isMainSquad) {
      unit.aiState = UnitAiState.rejoinTeam;
      unit.desiredVelocity.setFrom(game.squads.teamCenter - unit.position);
      if (game.squads.isInsideMainArmy(unit.position)) {
        unit.isMainSquad = true;
      }
      return;
    }
    unit.aiState = UnitAiState.idleWithTeam;
    _cohese(game, unit);
  }

  static void _isolatedOrRejoin(NecromancyGame game, UnitComponent unit) {
    final melee = _hostileInMelee(game, unit);
    if (melee != null) {
      _engage(game, unit, melee);
      return;
    }
    unit.clearTarget();
    unit.aiState = UnitAiState.rejoinTeam;
    unit.desiredVelocity.setFrom(game.squads.teamCenter - unit.position);
    if (game.squads.isInsideMainArmy(unit.position)) {
      unit.isMainSquad = true;
      unit.aiState = UnitAiState.idleWithTeam;
    }
  }

  static void _updateMembership(NecromancyGame game, UnitComponent unit) {
    if (!unit.isMainSquad || unit.isFighting || unit.regroupTimer > 0) {
      return;
    }
    if (game.squads.hostilesInSight(unit, game.spatial).isNotEmpty) {
      return;
    }
    final main = game.squads.cachedMainFriendlies;
    if (main.length <= 1) {
      return;
    }
    final dists = [
      for (final member in main)
        member.position.distanceTo(game.squads.teamCenter),
    ]..sort();
    final median = dists[dists.length ~/ 2];
    final dist = unit.position.distanceTo(game.squads.teamCenter);
    final breakDistance = max(320.0, median * GameConfig.detachedDistanceFactor);
    if (dist > breakDistance) {
      unit.isMainSquad = false;
      unit.aiState = UnitAiState.rejoinTeam;
      unit.clearTarget();
    }
  }

  static void _engage(
    NecromancyGame game,
    UnitComponent unit,
    UnitComponent target,
  ) {
    if (_shouldAbortChase(game, unit, target)) {
      unit.chaseAbortCooldown = GameConfig.chaseAbortCooldown;
      unit.clearTarget();
      unit.aiState = UnitAiState.idleWithTeam;
      _cohese(game, unit);
      return;
    }
    if (unit.isRanged) {
      WizardAi.pursue(game, unit, target);
      return;
    }
    game.squads.markChaseStart(unit);
    if (game.targeting.inAttackRange(unit, target)) {
      unit.aiState = UnitAiState.attackTarget;
      game.combat.tryAttack(unit, target);
      // Stay glued to the target so separation cannot walk them out of range.
      final desiredGap = unit.physicalRadius + target.physicalRadius + 6;
      final delta = target.position - unit.position;
      if (delta.length > desiredGap) {
        unit.desiredVelocity.setFrom(delta);
      } else {
        unit.desiredVelocity.setZero();
      }
      return;
    }
    if (!game.targeting.hasMeleeSlot(unit, target)) {
      unit.aiState = UnitAiState.searchReachableTarget;
      final fallback = game.targeting.evaluate(unit);
      if (fallback != null && fallback.id != target.id) {
        unit.currentTargetId = fallback.id;
        unit.desiredVelocity.setFrom(fallback.position - unit.position);
        return;
      }
      final along = target.position - unit.position;
      if (along.length2 > 1) {
        along.normalize();
        final perp = Vector2(-along.y, along.x);
        if (unit.id.isOdd) {
          perp.scale(-1);
        }
        unit.desiredVelocity.setFrom(along * 0.72 + perp * 0.55);
        return;
      }
    }
    unit.aiState = UnitAiState.chaseTarget;
    unit.desiredVelocity.setFrom(target.position - unit.position);
  }

  static bool _shouldAbortChase(
    NecromancyGame game,
    UnitComponent unit,
    UnitComponent target,
  ) {
    if (game.targeting.inAttackRange(unit, target)) {
      return false;
    }
    if (unit.position.distanceTo(target.position) <= unit.effectiveSight) {
      return false;
    }
    return game.squads.chaseExceeded(unit);
  }

  static UnitComponent? _hostileInMelee(
    NecromancyGame game,
    UnitComponent unit,
  ) {
    final hostiles = game.squads.hostilesInSight(unit, game.spatial);
    for (final hostile in hostiles) {
      if (game.targeting.inAttackRange(unit, hostile)) {
        return hostile;
      }
    }
    return null;
  }

  static void _cohese(NecromancyGame game, UnitComponent unit) {
    final slot = game.squads.formationSlotFor(unit);
    final delta = slot - unit.position;
    if (delta.length > 10) {
      unit.desiredVelocity.setFrom(delta);
    }
  }
}
