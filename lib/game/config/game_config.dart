import 'dart:ui';

import 'package:flame/components.dart';

import '../models/settings_data.dart';

/// World, camera, crowd, and combat tunables. Balance numbers that belong to
/// a unit type live in `unit_definitions.dart` instead.
class GameConfig {
  GameConfig._();

  static const double worldWidth = 4800;
  static const double worldHeight = 4800;
  static const double worldMargin = 28;

  static const double cameraLerp = 5.2;
  static const double cameraZoomClose = 1.15;
  static const double cameraZoomNormal = 0.82;
  static const double cameraZoomFar = 0.55;
  static const CameraZoomPreset defaultZoom = CameraZoomPreset.normal;

  static double zoomValue(CameraZoomPreset preset) {
    switch (preset) {
      case CameraZoomPreset.close:
        return cameraZoomClose;
      case CameraZoomPreset.normal:
        return cameraZoomNormal;
      case CameraZoomPreset.far:
        return cameraZoomFar;
    }
  }

  static const double friendlySpeedMultiplier = 1.06;
  static const double enemySpeedMultiplier = 1.00;
  static const double friendlySightMultiplier = 1.00;
  static const double enemySightMultiplier = 1.00;

  static const double joystickDeadzone = 0.22;
  static const double joystickCommitThreshold = 0.42;
  static const double joystickOpacity = 0.28;
  static const double joystickKnobOpacity = 0.45;

  static const double orderArriveDistance = 52;
  static const double disengageMin = 0.08;
  static const double disengageMax = 0.48;
  static const double committedAttackDuration = 0.18;

  static const double chaseDistanceMultiplier = 4.5;
  static const double chaseAbortCooldown = 0.45;

  static const double cohesionMargin = 36;
  static const double teamRadiusPaddingFactor = 1.20;
  static const double joinMargin = 48;
  static const double detachedDistanceFactor = 2.35;
  static const double formationSpacing = 22;
  static const double cohesionWeight = 0.35;
  static const double separationWeight = 1.15;
  static const int overlapResolveIterations = 3;

  static const double targetEvalInterval = 0.2;
  static const double targetSwitchHysteresis = 0.82;
  static const double assistArrivalDistance = 70;

  static const double hitFlashDuration = 0.38;
  static const double graveSize = 12;
  static const double resurrectionDuration = 1.25;
  static const double resurrectionStagger = 0.16;
  static const double spawnRevealDuration = 0.55;
  static const double squadInspectDuration = 1.5;
  static const double squadInspectClickRadius = 36;

  static const int startingMiniKnights = 5;
  static Vector2 get startingPosition =>
      Vector2(worldWidth / 2, worldHeight / 2);

  static const Color friendlyFill = Color(0xFFB07CFF);
  static const Color friendlyStroke = Color(0xFF3B1768);
  static const Color enemyFill = Color(0xFFD0D0D6);
  static const Color enemyStroke = Color(0xFF5A5A62);
  static const Color graveFill = Color(0xFF7A7480);
  static const Color resurrectionLight = Color(0xFFE8D0FF);
  static const Color worldFill = Color(0xFF1A1F18);
  static const Color worldGrid = Color(0xFF2A3326);
  static const Color worldBorder = Color(0xFF5A6A50);
}

class WorldBounds {
  WorldBounds._();

  static Vector2 clamp(Vector2 position, double radius) {
    return Vector2(
      position.x.clamp(
        GameConfig.worldMargin + radius,
        GameConfig.worldWidth - GameConfig.worldMargin - radius,
      ),
      position.y.clamp(
        GameConfig.worldMargin + radius,
        GameConfig.worldHeight - GameConfig.worldMargin - radius,
      ),
    );
  }

  static bool contains(Vector2 position) {
    return position.x >= 0 &&
        position.y >= 0 &&
        position.x <= GameConfig.worldWidth &&
        position.y <= GameConfig.worldHeight;
  }

  static Vector2 randomPoint(
    Vector2 Function() nextVec, {
    double margin = 80,
  }) {
    final p = nextVec();
    return Vector2(
      margin + p.x * (GameConfig.worldWidth - margin * 2),
      margin + p.y * (GameConfig.worldHeight - margin * 2),
    );
  }
}
