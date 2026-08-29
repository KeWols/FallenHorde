import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../necromancy_game.dart';

class SquadInspectLayer extends Component with HasGameReference<NecromancyGame> {
  SquadInspectLayer() : super(priority: 85);

  @override
  void render(Canvas canvas) {
    if (game.inspectTimer <= 0 || game.inspectedSquadId == null) {
      return;
    }
    final squad = game.squads.enemySquads[game.inspectedSquadId!];
    if (squad == null) {
      return;
    }
    final living = [for (final m in squad.members) if (m.isAlive) m];
    if (living.isEmpty) {
      return;
    }
    final ring = Paint()
      ..color = const Color(0xE6FF2A22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6;
    for (final unit in living) {
      canvas.drawCircle(
        Offset(unit.position.x, unit.position.y),
        unit.physicalRadius + 6,
        ring,
      );
    }
    final center = squad.center;
    final label = '${living.length}';
    final painter = TextPainter(
      text: TextSpan(
        text: 'Squad: $label',
        style: const TextStyle(
          color: Color(0xFFFFF5F3),
          fontSize: 16,
          fontWeight: FontWeight.w800,
          shadows: [
            Shadow(color: Color(0xFF7A1010), blurRadius: 8),
            Shadow(color: Color(0xCC000000), blurRadius: 3),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final bg = Rect.fromCenter(
      center: Offset(center.x, center.y - 28),
      width: painter.width + 16,
      height: painter.height + 10,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bg, const Radius.circular(8)),
      Paint()..color = const Color(0xCC1A0A0A),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bg, const Radius.circular(8)),
      Paint()
        ..color = const Color(0xAAFF2A22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    painter.paint(
      canvas,
      Offset(bg.left + 8, bg.top + 5),
    );
  }
}
