import 'package:flutter/material.dart';

import '../necromancy_game.dart';

class HudOverlay extends StatefulWidget {
  const HudOverlay({super.key, required this.game});

  final NecromancyGame game;

  @override
  State<HudOverlay> createState() => _HudOverlayState();
}

class _HudOverlayState extends State<HudOverlay> {
  @override
  void initState() {
    super.initState();
    widget.game.onHudTick = _onTick;
  }

  @override
  void didUpdateWidget(HudOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game != widget.game) {
      oldWidget.game.onHudTick = null;
      widget.game.onHudTick = _onTick;
    }
  }

  @override
  void dispose() {
    widget.game.onHudTick = null;
    super.dispose();
  }

  void _onTick() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return SafeArea(
      child: Stack(
        children: [
          if (game.useJoystick && !game.isGameOver && !game.isPaused)
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Material(
                  color: const Color(0xCC11150F),
                  shape: const CircleBorder(
                    side: BorderSide(color: Color(0x5534C6FF)),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: game.togglePauseMenu,
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.pause,
                        color: Color(0xFFEDE8D8),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xAA11150F),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x5534C6FF)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: DefaultTextStyle(
                      style: const TextStyle(
                        color: Color(0xFFEDE8D8),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Current Score  ${game.score.currentScore}'),
                          Text('Max Score  ${game.score.maxScore}'),
                          if (game.settings.showDebug) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Friendly ${game.friendlyCount}   Squads ${game.enemySquadCount}   FPS ${game.fps.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFFB7C4AE),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
