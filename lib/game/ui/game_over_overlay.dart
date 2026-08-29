import 'package:flutter/material.dart';

import '../necromancy_game.dart';

class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({super.key, required this.game});

  final NecromancyGame game;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x99000000),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF161B14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF4E5C46)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'GAME OVER',
                    style: TextStyle(
                      color: Color(0xFFEDE8D8),
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'MAX SCORE',
                    style: TextStyle(
                      color: Color(0xFF9AA890),
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    '${game.score.maxScore}',
                    style: const TextStyle(
                      color: Color(0xFF7CFFB2),
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        await game.submitScoreIfNeeded();
                        await game.restartRun();
                      },
                      child: const Text('RESTART'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        await game.submitScoreIfNeeded();
                        game.onExitToMenu();
                      },
                      child: const Text('MAIN MENU'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
