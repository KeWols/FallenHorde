import 'package:flame/components.dart';

import '../components/units/unit_component.dart';
import '../config/game_config.dart';
import '../models/ai_state.dart';
import '../necromancy_game.dart';
import 'wizard_ai.dart';

class EnemyAi {
  static void step(NecromancyGame game, UnitComponent unit) {
    final target = game.targeting.evaluate(unit);
    if (target != null) {
      _engage(game, unit, target);
      return;
    }
    if (unit.assistMateId != null) {
      final mate = game.squads.findById(game.world.units, unit.assistMateId);
      if (mate != null) {
        unit.aiState = UnitAiState.assistSubteam;
        unit.desiredVelocity.setFrom(mate.position - unit.position);
        return;
      }
    }

    final squad = game.squads.squadOf(unit);
    if (squad == null) {
      unit.aiState = UnitAiState.patrol;
      return;
    }
    unit.clearTarget();
    unit.aiState = squad.inCombat
        ? UnitAiState.returnToPatrol
        : UnitAiState.patrol;
    final slot = game.squads.formationSlotFor(unit);
    unit.desiredVelocity.setFrom(slot - unit.position);
    _nudgeOffWall(unit);
  }

  static void _engage(
    NecromancyGame game,
    UnitComponent unit,
    UnitComponent target,
  ) {
    if (_shouldAbortChase(game, unit, target)) {
      unit.chaseAbortCooldown = GameConfig.chaseAbortCooldown;
      unit.clearTarget();
      unit.aiState = UnitAiState.returnToPatrol;
      final squad = game.squads.squadOf(unit);
      if (squad != null) {
        unit.desiredVelocity.setFrom(squad.center - unit.position);
      }
      _nudgeOffWall(unit);
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
      final desiredGap = unit.physicalRadius + target.physicalRadius + 6;
      final delta = target.position - unit.position;
      if (delta.length > desiredGap) {
        unit.desiredVelocity.setFrom(delta);
      } else {
        unit.desiredVelocity.setZero();
      }
      _nudgeOffWall(unit);
      return;
    }
    if (!game.targeting.hasMeleeSlot(unit, target)) {
      unit.aiState = UnitAiState.searchReachableTarget;
      final along = target.position - unit.position;
      if (along.length2 > 1) {
        along.normalize();
        final perp = Vector2(-along.y, along.x);
        if (unit.id.isOdd) {
          perp.scale(-1);
        }
        unit.desiredVelocity.setFrom(along * 0.72 + perp * 0.55);
        _nudgeOffWall(unit);
        return;
      }
    } else {
      unit.aiState = UnitAiState.chaseTarget;
    }
    unit.desiredVelocity.setFrom(target.position - unit.position);
    _nudgeOffWall(unit);
  }

  static void _nudgeOffWall(UnitComponent unit) {
    const edge = 110.0;
    final p = unit.position;
    if (p.x < edge) {
      unit.desiredVelocity.x += 1.2;
    } else if (p.x > GameConfig.worldWidth - edge) {
      unit.desiredVelocity.x -= 1.2;
    }
    if (p.y < edge) {
      unit.desiredVelocity.y += 1.2;
    } else if (p.y > GameConfig.worldHeight - edge) {
      unit.desiredVelocity.y -= 1.2;
    }
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
}
