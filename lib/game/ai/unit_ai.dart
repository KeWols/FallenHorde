import '../components/units/unit_component.dart';
import '../necromancy_game.dart';
import 'enemy_ai.dart';
import 'friendly_ai.dart';

class UnitAi {
  UnitAi(this.game);

  final NecromancyGame game;

  void update(UnitComponent unit, double dt) {
    unit.desiredVelocity.setZero();
    if (!unit.isAlive) {
      return;
    }
    if (unit.isFriendly) {
      FriendlyAi.step(game, unit);
    } else {
      EnemyAi.step(game, unit);
    }
    if (unit.desiredVelocity.length2 > 0) {
      unit.desiredVelocity.normalize();
    }
  }
}
