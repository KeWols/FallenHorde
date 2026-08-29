import 'package:flutter/material.dart';

import 'game_screen.dart';
import 'scoreboard_screen.dart';
import 'settings_screen.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12160F),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'FALLEN HORDE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFEDE8D8),
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Grow the army. Choose your battles.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF9AA890)),
                  ),
                  const SizedBox(height: 36),
                  _MenuButton(
                    label: 'PLAY',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const GameScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _MenuButton(
                    label: 'SCOREBOARD',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ScoreboardScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _MenuButton(
                    label: 'SETTINGS',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
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

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
