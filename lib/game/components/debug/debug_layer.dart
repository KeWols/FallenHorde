import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../models/ai_state.dart';
import '../../models/faction.dart';
import '../../necromancy_game.dart';

class DebugLayer extends Component with HasGameReference<NecromancyGame> {
  DebugLayer() : super(priority: 80);

  @override
  void render(Canvas canvas) {
    if (!game.settings.showDebug) {
      return;
    }
    final teamPaint = Paint()
      ..color = const Color(0x6634C6FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(
      Offset(game.squads.teamCenter.x, game.squads.teamCenter.y),
      game.squads.teamRadius,
      teamPaint,
    );
    canvas.drawCircle(
      Offset(game.squads.teamCenter.x, game.squads.teamCenter.y),
      6,
      Paint()..color = const Color(0xCC34C6FF),
    );

    for (final unit in game.world.living) {
      final origin = Offset(unit.position.x, unit.position.y);
      _circle(canvas, origin, unit.physicalRadius, const Color(0x66FFFFFF));
      _circle(canvas, origin, unit.effectiveSight, const Color(0x33FFF59D));
      _circle(
        canvas,
        origin,
        unit.isRanged
            ? unit.stats.attackRadius
            : unit.stats.attackRadius + 12,
        const Color(0x55FF8A80),
      );
      final target = game.squads.findById(game.world.units, unit.currentTargetId);
      if (target != null) {
        canvas.drawLine(
          origin,
          Offset(target.position.x, target.position.y),
          Paint()
            ..color = const Color(0xAAFFEB3B)
            ..strokeWidth = 1.2,
        );
      }
      if (unit.isEnemy && unit.subEnemyId != null) {
        final hue = (unit.subEnemyId! * 47) % 360;
        canvas.drawCircle(
          origin,
          unit.physicalRadius + 3,
          Paint()
            ..color = HSVColor.fromAHSV(0.85, hue.toDouble(), 0.7, 1).toColor()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
      if (unit.isFriendly && !unit.isMainSquad) {
        canvas.drawCircle(
          origin,
          unit.physicalRadius + 5,
          Paint()
            ..color = const Color(0xAAFFFFFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
      _stateMark(canvas, origin, unit.aiState, unit.faction);
    }
  }

  void _circle(Canvas canvas, Offset origin, double radius, Color color) {
    canvas.drawCircle(
      origin,
      radius,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _stateMark(
    Canvas canvas,
    Offset origin,
    UnitAiState state,
    Faction faction,
  ) {
    final color = switch (state) {
      UnitAiState.attackTarget || UnitAiState.shoot => const Color(0xFFFF5252),
      UnitAiState.chaseTarget || UnitAiState.detectEnemy => const Color(0xFFFFC107),
      UnitAiState.assistTeammate || UnitAiState.assistSubteam => const Color(0xFF7C4DFF),
      UnitAiState.patrol || UnitAiState.idleWithTeam => const Color(0xFF69F0AE),
      UnitAiState.rejoinTeam || UnitAiState.detached => const Color(0xFF80D8FF),
      UnitAiState.followPlayerOrder => const Color(0xFFE1F5FE),
      _ => const Color(0xFFBDBDBD),
    };
    canvas.drawCircle(origin + const Offset(0, -18), 3.2, Paint()..color = color);
  }
}
