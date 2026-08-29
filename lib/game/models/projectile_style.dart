import 'package:flutter/material.dart';

import '../services/game_rng.dart';

/// Visual kit for a wizard bolt. Add a new const to [ProjectileCatalog.all]
/// and every freshly spawned wizard can roll it.
class ProjectileStyle {
  const ProjectileStyle({
    required this.id,
    required this.core,
    required this.glow,
    required this.trail,
    required this.impactHot,
    required this.impactCool,
    required this.spark,
  });

  final String id;
  final Color core;
  final Color glow;
  final Color trail;
  final Color impactHot;
  final Color impactCool;
  final Color spark;
}

class ProjectileCatalog {
  ProjectileCatalog._();

  static const blackWhite = ProjectileStyle(
    id: 'blackWhite',
    core: Color(0xFFF4F4F8),
    glow: Color(0xFF1A1A1E),
    trail: Color(0xFFB8B8C4),
    impactHot: Color(0xFFFFFFFF),
    impactCool: Color(0xFF141418),
    spark: Color(0xFFE8E8EE),
  );

  static const lightBlue = ProjectileStyle(
    id: 'lightBlue',
    core: Color(0xFFE8F7FF),
    glow: Color(0xFF5EC8FF),
    trail: Color(0xFF9BDFFF),
    impactHot: Color(0xFFFFFFFF),
    impactCool: Color(0xFF3AA0E8),
    spark: Color(0xFFB8ECFF),
  );

  static const fire = ProjectileStyle(
    id: 'fire',
    core: Color(0xFFFFF1C2),
    glow: Color(0xFFFF6A2A),
    trail: Color(0xFF4A9CFF),
    impactHot: Color(0xFFFFF4D2),
    impactCool: Color(0xFF2F6AE8),
    spark: Color(0xFFFF8A3A),
  );

  static const darkPurple = ProjectileStyle(
    id: 'darkPurple',
    core: Color(0xFFF0D4FF),
    glow: Color(0xFF6B1AB8),
    trail: Color(0xFFB07CFF),
    impactHot: Color(0xFFF8E8FF),
    impactCool: Color(0xFF3B1768),
    spark: Color(0xFFC9A0FF),
  );

  static const green = ProjectileStyle(
    id: 'green',
    core: Color(0xFFE8FFD4),
    glow: Color(0xFF2BB673),
    trail: Color(0xFF7CFFB2),
    impactHot: Color(0xFFF2FFE8),
    impactCool: Color(0xFF146B42),
    spark: Color(0xFF9CFFC4),
  );

  static const white = ProjectileStyle(
    id: 'white',
    core: Color(0xFFFFFFFF),
    glow: Color(0xFFE8EEF8),
    trail: Color(0xFFD0D8E8),
    impactHot: Color(0xFFFFFFFF),
    impactCool: Color(0xFFC8D2E4),
    spark: Color(0xFFF6F8FF),
  );

  /// Expand this list when adding new bolt animations.
  static const List<ProjectileStyle> all = [
    blackWhite,
    lightBlue,
    fire,
    darkPurple,
    green,
    white,
  ];

  static ProjectileStyle pick(GameRng rng) => rng.pick(all);
}
