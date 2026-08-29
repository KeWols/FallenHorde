import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'ai/unit_ai.dart';
import 'components/debug/debug_layer.dart';
import 'components/debug/squad_inspect_layer.dart';
import 'components/units/unit_component.dart';
import 'components/world/destination_marker.dart';
import 'components/world/world_backdrop.dart';
import 'config/game_config.dart';
import 'config/unit_definitions.dart';
import 'game_world.dart';
import 'models/ai_state.dart';
import 'models/faction.dart';
import 'models/settings_data.dart';
import 'models/unit_type.dart';
import 'services/game_rng.dart';
import 'systems/combat_system.dart';
import 'systems/movement_system.dart';
import 'systems/necromancy_system.dart';
import 'systems/score_system.dart';
import 'systems/spawn_system.dart';
import 'systems/spatial_grid.dart';
import 'systems/squad_system.dart';
import 'systems/targeting_system.dart';
import 'ui/army_joystick.dart';

class NecromancyGame extends FlameGame<GameWorld>
    with SecondaryTapCallbacks, TapCallbacks, KeyboardEvents {
  NecromancyGame({
    required this.settings,
    required this.onExitToMenu,
    required this.onGameOverScore,
  }) : super(world: GameWorld());

  SettingsData settings;
  final VoidCallback onExitToMenu;
  final Future<void> Function(int maxScore) onGameOverScore;

  late final GameRng rng;
  late final SpatialGrid spatial;
  late final SquadSystem squads;
  late final TargetingSystem targeting;
  late final CombatSystem combat;
  late final MovementSystem movement;
  late final NecromancySystem necromancy;
  late final SpawnSystem spawner;
  late final ScoreSystem score;
  late final UnitAi ai;
  late final DestinationMarker destinationMarker;

  ArmyJoystick? joystick;
  bool isGameOver = false;
  bool isPaused = false;
  bool _gameOverHandled = false;
  bool _scoreSubmitted = false;
  double fps = 60;
  VoidCallback? onHudTick;
  int get friendlyCount => world.livingFriendlies.length;
  int get enemySquadCount => squads.enemySquads.length;

  bool _enemiesSpawned = false;
  bool _hadLivingFriendlies = false;
  bool _runReady = false;
  bool _joystickWasActive = false;
  bool _joystickWasCommit = false;

  int? inspectedSquadId;
  double inspectTimer = 0;
  int? _lastTapMs;
  Vector2? _lastTapCanvas;

  bool get useJoystick =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    rng = GameRng(settings.rngSeed);
    spatial = SpatialGrid();
    squads = SquadSystem();
    targeting = TargetingSystem(this);
    combat = CombatSystem(this);
    movement = MovementSystem(this);
    necromancy = NecromancySystem(this);
    spawner = SpawnSystem(this);
    score = ScoreSystem(this);
    ai = UnitAi(this);

    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.zoom = GameConfig.zoomValue(settings.cameraZoom);
    camera.viewfinder.position = GameConfig.startingPosition.clone();

    await world.add(WorldBackdrop());
    destinationMarker = DestinationMarker();
    await world.add(destinationMarker);
    await world.add(DebugLayer());
    await world.add(SquadInspectLayer());

    if (useJoystick) {
      joystick = ArmyJoystick();
      camera.viewport.add(joystick!);
    }

    await _startRun();
  }

  void applySettings(SettingsData next) {
    settings = next;
    camera.viewfinder.zoom = GameConfig.zoomValue(settings.cameraZoom);
    rng.reseed(settings.rngSeed);
  }

  Future<void> restartRun() async {
    overlays.remove('gameOver');
    overlays.remove('pause');
    isGameOver = false;
    isPaused = false;
    _gameOverHandled = false;
    _scoreSubmitted = false;
    _hadLivingFriendlies = false;
    _runReady = false;
    // Removals only complete while the engine is ticking. Game Over / Pause
    // already paused it, so waiting on `removed` here would hang forever.
    if (paused) {
      resumeEngine();
    }
    await _clearRun();
    await _startRun();
  }

  Future<void> _startRun() async {
    final origin = GameConfig.startingPosition.clone();
    camera.viewfinder.position = origin.clone();
    const golden = 2.399963;
    final starters = <UnitComponent>[];
    for (var i = 0; i < GameConfig.startingMiniKnights; i++) {
      final r = i == 0 ? 0.0 : GameConfig.formationSpacing * sqrt(i + 0.2);
      final a = i * golden;
      final unit = UnitComponent(
        id: squads.allocateUnitId(),
        type: UnitType.miniKnight,
        faction: Faction.friendly,
        startPosition: WorldBounds.clamp(
          origin + Vector2(cos(a) * r, sin(a) * r),
          UnitCatalog.stats(UnitType.miniKnight).physicalRadius,
        ),
        isMainSquad: true,
      );
      unit.aiState = UnitAiState.idleWithTeam;
      unit.hp = UnitCatalog.stats(UnitType.miniKnight).maxHp;
      starters.add(unit);
    }
    await world.addAll(starters);
    squads.recompute(world.units);
    final center = squads.teamCenter.length2 < 1
        ? origin
        : squads.teamCenter.clone();
    camera.viewfinder.position = center;
    score.beginRun();
    _enemiesSpawned = false;
    _hadLivingFriendlies = world.livingFriendlies.isNotEmpty;
    _runReady = true;
  }

  Future<void> _clearRun() async {
    _runReady = false;
    final pending = <Future<void>>[];
    for (final child in world.children.toList()) {
      if (child is WorldBackdrop ||
          child is DestinationMarker ||
          child is DebugLayer ||
          child is SquadInspectLayer) {
        continue;
      }
      if (!child.isMounted) {
        continue;
      }
      pending.add(child.removed);
      child.removeFromParent();
    }
    if (pending.isNotEmpty) {
      try {
        await Future.wait(pending).timeout(const Duration(milliseconds: 1500));
      } on TimeoutException {
        // A paused engine used to hang here forever; keep reset unblocking.
      }
    }
    world.units.clear();
    world.graves.clear();
    world.projectiles.clear();
    combat.reset();
    spatial.clear();
    squads.reset();
    necromancy.reset();
    spawner.reset();
    score.reset();
    destinationMarker.hideMarker();
    camera.viewfinder.position = GameConfig.startingPosition.clone();
    _enemiesSpawned = false;
    _hadLivingFriendlies = false;
    inspectedSquadId = null;
    inspectTimer = 0;
    _lastTapMs = null;
    _lastTapCanvas = null;
    _joystickWasActive = false;
    _joystickWasCommit = false;
  }

  @override
  void update(double dt) {
    if (isGameOver || isPaused || !_runReady) {
      super.update(dt);
      onHudTick?.call();
      return;
    }
    if (dt > 0) {
      fps = fps * 0.9 + (1 / dt) * 0.1;
    }
    if (!_enemiesSpawned &&
        camera.isMounted &&
        size.x > 0 &&
        world.livingFriendlies.isNotEmpty) {
      squads.recompute(world.units);
      camera.viewfinder.position = squads.teamCenter.clone();
      spawner.populateInitial();
      _enemiesSpawned = true;
    }
    if (inspectTimer > 0) {
      inspectTimer -= dt;
      if (inspectTimer <= 0) {
        inspectedSquadId = null;
      }
    }
    _pollInput();
    _rebuildSpatial();
    squads.recompute(world.units);
    _updateCamera(dt);
    for (final unit in world.living) {
      ai.update(unit, dt);
    }
    movement.step(dt);
    _rebuildSpatial();
    combat.tickProjectiles(dt);
    necromancy.sweep();
    spawner.tick(dt);
    score.syncFromLiving();
    _checkGameOver();
    super.update(dt);
    onHudTick?.call();
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (isGameOver || isPaused) {
      return;
    }
    if (_isJoystickTap(event.canvasPosition)) {
      return;
    }
    final canvasPos = event.canvasPosition;
    final worldPos = camera.globalToLocal(canvasPos);
    final now = DateTime.now().millisecondsSinceEpoch;
    final isDoubleTap = _lastTapMs != null &&
        _lastTapCanvas != null &&
        now - _lastTapMs! <= (GameConfig.doubleTapWindow * 1000).round() &&
        canvasPos.distanceTo(_lastTapCanvas!) <= 52;
    _lastTapMs = now;
    _lastTapCanvas = canvasPos.clone();
    if (isDoubleTap &&
        useJoystick &&
        settings.focusHuntOnCommand &&
        _tryFocusHunt(worldPos)) {
      return;
    }
    final allowInspect = useJoystick || settings.inspectSquadOnClick;
    if (!allowInspect) {
      return;
    }
    _inspectSquadAt(worldPos);
  }

  @override
  void onSecondaryTapDown(SecondaryTapDownEvent event) {
    if (isGameOver || isPaused || useJoystick) {
      return;
    }
    final worldPos = camera.globalToLocal(event.canvasPosition);
    if (settings.focusHuntOnCommand && _tryFocusHunt(worldPos)) {
      return;
    }
    final clamped = WorldBounds.clamp(worldPos, 0);
    squads.setClickOrder(clamped);
    squads.moveOrderSerial++;
    destinationMarker.showAt(clamped);
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyD) {
      settings = settings.copyWith(showDebug: !settings.showDebug);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void togglePauseMenu() {
    if (isGameOver) {
      return;
    }
    if (isPaused) {
      resumeFromPause();
    } else {
      _enterPause();
    }
  }

  void _enterPause() {
    if (isPaused || isGameOver) {
      return;
    }
    isPaused = true;
    overlays.add('pause');
    pauseEngine();
    onHudTick?.call();
  }

  void resumeFromPause() {
    if (!isPaused || isGameOver) {
      return;
    }
    isPaused = false;
    overlays.remove('pause');
    resumeEngine();
  }

  Future<void> giveUpToMenu() async {
    overlays.remove('pause');
    isPaused = false;
    try {
      await submitScoreIfNeeded();
    } finally {
      onExitToMenu();
    }
  }

  Future<void> submitScoreIfNeeded() async {
    if (_scoreSubmitted) {
      return;
    }
    _scoreSubmitted = true;
    final recorded = score.maxScore;
    await onGameOverScore(recorded);
  }

  void _pollInput() {
    final stick = joystick;
    if (stick == null) {
      if (!squads.hasMoveOrder) {
        destinationMarker.hideMarker();
      }
      return;
    }
    final intensity = stick.intensity;
    if (intensity < GameConfig.joystickDeadzone) {
      if (_joystickWasActive) {
        squads.clearMoveOrder();
        destinationMarker.hideMarker();
      }
      _joystickWasActive = false;
      _joystickWasCommit = false;
      return;
    }
    final dir = stick.relativeDelta;
    if (dir.length2 == 0) {
      return;
    }
    final commit = intensity >= GameConfig.joystickCommitThreshold;
    if (!_joystickWasActive || (commit && !_joystickWasCommit)) {
      squads.moveOrderSerial++;
    }
    squads.setJoystickOrder(dir, intensity);
    _joystickWasActive = true;
    _joystickWasCommit = commit;
    destinationMarker.hideMarker();
  }

  void _updateCamera(double dt) {
    camera.viewfinder.zoom = GameConfig.zoomValue(settings.cameraZoom);
    if (world.livingFriendlies.isEmpty) {
      return;
    }
    final t = (1 - exp(-GameConfig.cameraLerp * dt)).clamp(0.0, 1.0);
    final current = camera.viewfinder.position;
    current.lerp(squads.teamCenter, t);
    camera.viewfinder.position = current;
  }

  void _inspectSquadAt(Vector2 worldPos) {
    final nearest = _enemyAt(worldPos);
    final squadId = nearest?.subEnemyId;
    if (nearest == null || squadId == null) {
      return;
    }
    inspectedSquadId = squadId;
    inspectTimer = GameConfig.squadInspectDuration;
  }

  bool _tryFocusHunt(Vector2 worldPos) {
    final nearest = _enemyAt(worldPos);
    final squadId = nearest?.subEnemyId;
    if (nearest == null || squadId == null) {
      return false;
    }
    squads.beginFocusHunt(squadId);
    inspectedSquadId = squadId;
    inspectTimer = GameConfig.squadInspectDuration;
    destinationMarker.hideMarker();
    for (final unit in world.livingFriendlies) {
      unit.targetEvalTimer = 0;
      unit.chaseAbortCooldown = 0;
    }
    return true;
  }

  UnitComponent? _enemyAt(Vector2 worldPos) {
    UnitComponent? nearest;
    var best = double.infinity;
    final extra = useJoystick ? 36.0 : 18.0;
    for (final unit in world.livingEnemies) {
      final reach = unit.physicalRadius + extra;
      final dist = unit.position.distanceToSquared(worldPos);
      if (dist <= reach * reach && dist < best) {
        best = dist;
        nearest = unit;
      }
    }
    return nearest;
  }

  bool _isJoystickTap(Vector2 canvasPos) {
    final stick = joystick;
    if (stick == null || !stick.isMounted) {
      return false;
    }
    return canvasPos.distanceTo(stick.absoluteCenter) <= 78;
  }

  void _rebuildSpatial() {
    spatial.clear();
    for (final unit in world.units) {
      spatial.insert(unit);
    }
  }

  void _checkGameOver() {
    if (world.livingFriendlies.isNotEmpty) {
      _hadLivingFriendlies = true;
    }
    if (!_hadLivingFriendlies || _gameOverHandled || !score.isGameOver) {
      return;
    }
    _gameOverHandled = true;
    isGameOver = true;
    destinationMarker.hideMarker();
    pauseEngine();
    overlays.add('gameOver');
    submitScoreIfNeeded();
  }
}
