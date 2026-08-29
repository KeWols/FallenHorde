import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import '../../config/game_config.dart';
import '../../config/unit_definitions.dart';
import '../../models/ai_state.dart';
import '../../models/animation_state.dart';
import '../../models/facing.dart';
import '../../models/faction.dart';
import '../../models/unit_stats.dart';
import '../../models/unit_type.dart';
import '../../necromancy_game.dart';
import 'placeholder_unit_view.dart';

class UnitComponent extends PositionComponent
    with HasGameReference<NecromancyGame> {
  UnitComponent({
    required this.id,
    required this.type,
    required this.faction,
    required Vector2 startPosition,
    this.subEnemyId,
    this.isMainSquad = false,
  }) : stats = UnitCatalog.stats(type),
       hp = UnitCatalog.stats(type).maxHp,
       super(
         position: startPosition,
         size: Vector2.all(UnitCatalog.stats(type).physicalRadius * 2),
         anchor: Anchor.center,
         priority: 10,
       );

  final int id;
  final UnitType type;
  Faction faction;
  int? subEnemyId;
  bool isMainSquad;
  final UnitStats stats;

  double hp;
  UnitAiState aiState = UnitAiState.idleWithTeam;
  UnitAnimState animState = UnitAnimState.idle;
  Facing facing = Facing.right;

  int? currentTargetId;
  int? assistMateId;
  int seenOrderSerial = 0;
  Vector2? chaseStartPosition;
  double chaseAbortCooldown = 0;
  double attackCooldown = 0;
  double committedAttackTimer = 0;
  double disengageTimer = 0;
  double hitFlashTimer = 0;
  double spawnRevealTimer = 0;
  double lastDamageTaken = 0;
  double targetEvalTimer = 0;
  double unreachableTimer = 0;

  final Vector2 desiredVelocity = Vector2.zero();
  final Vector2 velocity = Vector2.zero();

  bool get isAlive => hp > 0 && aiState != UnitAiState.dead;
  bool get isFriendly => faction.isFriendly;
  bool get isEnemy => faction.isEnemy;
  bool get isRanged => stats.isRanged;
  bool get broadcastsAssistance => isFriendly ? isMainSquad : true;
  bool get isFighting =>
      aiState == UnitAiState.chaseTarget ||
      aiState == UnitAiState.attackTarget ||
      aiState == UnitAiState.detectEnemy ||
      aiState == UnitAiState.assistTeammate ||
      aiState == UnitAiState.assistSubteam ||
      aiState == UnitAiState.searchReachableTarget ||
      aiState == UnitAiState.findRangedTarget ||
      aiState == UnitAiState.positionForRange ||
      aiState == UnitAiState.shoot;

  double get physicalRadius => stats.physicalRadius;

  double get effectiveSpeed {
    final mul = isFriendly
        ? GameConfig.friendlySpeedMultiplier
        : GameConfig.enemySpeedMultiplier;
    return stats.movementSpeed * mul;
  }

  double get effectiveSight {
    final mul = isFriendly
        ? GameConfig.friendlySightMultiplier
        : GameConfig.enemySightMultiplier;
    return stats.sightRadius * mul;
  }

  double get maxChaseDistance =>
      effectiveSight * GameConfig.chaseDistanceMultiplier;

  @override
  Future<void> onLoad() async {
    await add(PlaceholderUnitView(unit: this));
  }

  @override
  void onMount() {
    super.onMount();
    game.world.registerUnit(this);
  }

  @override
  void onRemove() {
    game.world.unregisterUnit(this);
    super.onRemove();
  }

  void takeDamage(double amount) {
    if (!isAlive) {
      return;
    }
    hp -= amount;
    lastDamageTaken = amount;
    hitFlashTimer = GameConfig.hitFlashDuration;
    if (hp <= 0) {
      hp = 0;
      aiState = UnitAiState.dead;
      animState = UnitAnimState.death;
    }
  }

  void clearTarget() {
    currentTargetId = null;
    assistMateId = null;
    chaseStartPosition = null;
    unreachableTimer = 0;
  }

  void faceFromVelocity() {
    if (velocity.x > 8) {
      facing = Facing.right;
    } else if (velocity.x < -8) {
      facing = Facing.left;
    }
  }

  void tickTimers(double dt) {
    if (attackCooldown > 0) {
      attackCooldown -= dt;
    }
    if (committedAttackTimer > 0) {
      committedAttackTimer -= dt;
    }
    if (disengageTimer > 0) {
      disengageTimer -= dt;
    }
    if (hitFlashTimer > 0) {
      hitFlashTimer -= dt;
    }
    if (spawnRevealTimer > 0) {
      spawnRevealTimer -= dt;
    }
    if (targetEvalTimer > 0) {
      targetEvalTimer -= dt;
    }
    if (chaseAbortCooldown > 0) {
      chaseAbortCooldown -= dt;
    }
  }

  @override
  @mustCallSuper
  void update(double dt) {
    super.update(dt);
    tickTimers(dt);
    if (!isAlive) {
      return;
    }
    if (velocity.length2 > 16) {
      animState = committedAttackTimer > 0
          ? UnitAnimState.attack
          : UnitAnimState.walk;
    } else if (committedAttackTimer > 0 || aiState == UnitAiState.attackTarget) {
      animState = UnitAnimState.attack;
    } else {
      animState = UnitAnimState.idle;
    }
    faceFromVelocity();
  }
}
