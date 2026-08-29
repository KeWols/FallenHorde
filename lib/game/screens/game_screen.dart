import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../necromancy_game.dart';
import '../persistence/scoreboard_storage.dart';
import '../persistence/settings_storage.dart';
import '../ui/game_over_overlay.dart';
import '../ui/hud_overlay.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  NecromancyGame? _game;
  final _settingsStorage = SettingsStorage();
  final _scoreboardStorage = ScoreboardStorage();

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final settings = await _settingsStorage.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _game = NecromancyGame(
        settings: settings,
        onExitToMenu: () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        },
        onGameOverScore: (maxScore) async {
          await _scoreboardStorage.maybeInsert(maxScore);
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    if (game == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF12160F),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF12160F),
      body: GameWidget<NecromancyGame>(
        game: game,
        autofocus: true,
        overlayBuilderMap: {
          'hud': (context, g) => HudOverlay(game: g),
          'gameOver': (context, g) => GameOverOverlay(game: g),
        },
        initialActiveOverlays: const ['hud'],
      ),
    );
  }
}
