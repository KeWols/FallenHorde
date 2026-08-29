import '../config/unit_definitions.dart';
import '../necromancy_game.dart';
import '../components/units/unit_component.dart';

class ScoreSystem {
  ScoreSystem(this.game);

  final NecromancyGame game;

  int currentScore = 0;
  int maxScore = 0;

  void reset() {
    currentScore = 0;
    maxScore = 0;
  }

  void beginRun() {
    currentScore = 0;
    maxScore = 0;
    for (final unit in game.world.livingFriendlies) {
      currentScore += unit.stats.scoreValue;
    }
    maxScore = currentScore;
  }

  void onConverted(UnitComponent unit) {
    final value = UnitCatalog.stats(unit.type).scoreValue;
    currentScore += value;
    maxScore += value;
  }

  void onFriendlyDeath(UnitComponent unit) {
    currentScore -= unit.stats.scoreValue;
    if (currentScore < 0) {
      currentScore = 0;
    }
  }

  void syncFromLiving() {
    var total = 0;
    for (final unit in game.world.livingFriendlies) {
      total += unit.stats.scoreValue;
    }
    currentScore = total;
  }

  bool get isCriticalRecovery => currentScore == 1;
  bool get isGameOver => game.world.livingFriendlies.isEmpty;
}
