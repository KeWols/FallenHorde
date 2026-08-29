import 'package:flame/components.dart';

import '../components/effects/resurrection_effect.dart';
import '../components/graves/grave_component.dart';
import '../components/units/unit_component.dart';
import '../config/game_config.dart';
import '../config/unit_definitions.dart';
import '../models/ai_state.dart';
import '../models/enemy_squad.dart';
import '../models/faction.dart';
import '../models/unit_type.dart';
import '../necromancy_game.dart';

class NecromancySystem {
  NecromancySystem(this.game);

  final NecromancyGame game;
  final Set<int> _handledDeaths = {};
  final Set<int> _resurrectingSquads = {};

  void reset() {
    _handledDeaths.clear();
    _resurrectingSquads.clear();
  }

  void handleDeath(UnitComponent unit) {
    if (!_handledDeaths.add(unit.id)) {
      return;
    }
    if (unit.isFriendly) {
      game.score.onFriendlyDeath(unit);
      unit.removeFromParent();
      return;
    }
    final squadId = unit.subEnemyId;
    if (squadId == null) {
      unit.removeFromParent();
      return;
    }
    final squad = game.squads.enemySquads[squadId];
    final grave = GraveComponent(
      originalUnitType: unit.type,
      originalSubEnemyId: squadId,
      deathPosition: unit.position.clone(),
    );
    squad?.members.remove(unit);
    squad?.graves.add(grave);
    unit.removeFromParent();
    if (squad != null && !squad.hasLivingMembers) {
      _tryResurrect(squad);
    } else {
      game.world.add(grave);
    }
  }

  /// Catches wipes and leftover corpses that still occupy the world.
  void sweep() {
    for (final unit in game.world.units.toList()) {
      if (!unit.isAlive) {
        handleDeath(unit);
      }
    }
    for (final squad in game.squads.enemySquads.values.toList()) {
      if (squad.eliminated || _resurrectingSquads.contains(squad.id)) {
        continue;
      }
      _tryResurrect(squad);
    }
  }

  void _tryResurrect(EnemySquad? squad) {
    if (squad == null || squad.eliminated) {
      return;
    }
    if (_resurrectingSquads.contains(squad.id)) {
      return;
    }
    if (squad.hasLivingMembers) {
      return;
    }
    _beginResurrection(squad);
  }

  void _beginResurrection(EnemySquad squad) {
    squad.eliminated = true;
    _resurrectingSquads.add(squad.id);
    final graves = List<GraveComponent>.from(squad.graves);
    if (graves.isEmpty) {
      game.squads.enemySquads.remove(squad.id);
      _resurrectingSquads.remove(squad.id);
      game.spawner.scheduleReplacement(squad.category);
      return;
    }
    for (var i = 0; i < graves.length; i++) {
      final grave = graves[i];
      final spawnType = grave.originalUnitType;
      final spawnAt = grave.position.clone();
      game.world.add(
        ResurrectionEffect(
          originalUnitType: spawnType,
          gravePosition: spawnAt,
          delay: i * GameConfig.resurrectionStagger,
          onEmerge: () => _spawnFriendly(spawnType, spawnAt),
        ),
      );
      grave.removeFromParent();
    }
    squad.graves.clear();
    game.squads.enemySquads.remove(squad.id);
    game.spawner.scheduleReplacement(squad.category);
    _resurrectingSquads.remove(squad.id);
  }

  void _spawnFriendly(UnitType type, Vector2 at) {
    final stats = UnitCatalog.stats(type);
    final unit = UnitComponent(
      id: game.squads.allocateUnitId(),
      type: type,
      faction: Faction.friendly,
      startPosition: at.clone(),
      isMainSquad: false,
    );
    final inside = game.squads.isInsideMainArmy(unit.position);
    unit.isMainSquad = inside;
    unit.aiState = inside ? UnitAiState.idleWithTeam : UnitAiState.rejoinTeam;
    unit.hp = stats.maxHp;
    unit.spawnRevealTimer = GameConfig.spawnRevealDuration;
    game.world.add(unit);
    game.score.onConverted(unit);
  }
}
