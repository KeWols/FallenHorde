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
      return;
    }
    if (!game.targeting.hasMeleeSlot(unit, target)) {
      unit.aiState = UnitAiState.searchReachableTarget;
    } else {
      unit.aiState = UnitAiState.chaseTarget;
    }
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
}
