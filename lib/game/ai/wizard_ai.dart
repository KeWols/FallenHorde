import '../components/units/unit_component.dart';
import '../models/ai_state.dart';
import '../necromancy_game.dart';

class WizardAi {
  static void pursue(
    NecromancyGame game,
    UnitComponent unit,
    UnitComponent target,
  ) {
    game.squads.markChaseStart(unit);
    final dist = unit.position.distanceTo(target.position);
    final ideal = unit.stats.attackRadius * 0.70;
    final tooClose = unit.stats.attackRadius * 0.36;
    if (dist < tooClose) {
      unit.desiredVelocity.setFrom(unit.position - target.position);
      unit.aiState = UnitAiState.positionForRange;
    } else if (dist > ideal) {
      unit.desiredVelocity.setFrom(target.position - unit.position);
      unit.aiState = UnitAiState.findRangedTarget;
    } else {
      unit.desiredVelocity.setZero();
      unit.aiState = UnitAiState.shoot;
    }
    if (game.targeting.inAttackRange(unit, target)) {
      if (game.combat.tryAttack(unit, target)) {
        unit.aiState = UnitAiState.shoot;
      } else if (unit.attackCooldown > 0) {
        unit.aiState = UnitAiState.rangedCooldown;
      }
    }
  }
}
