import 'package:flutter/material.dart';

import '../models/scoreboard_entry.dart';
import '../persistence/scoreboard_storage.dart';

class ScoreboardScreen extends StatefulWidget {
  const ScoreboardScreen({super.key});

  @override
  State<ScoreboardScreen> createState() => _ScoreboardScreenState();
}

class _ScoreboardScreenState extends State<ScoreboardScreen> {
  final _storage = ScoreboardStorage();
  late Future<List<ScoreboardEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _storage.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12160F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B2218),
        title: const Text('Scoreboard'),
      ),
      body: FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          final entries = snapshot.data;
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (entries == null || entries.isEmpty) {
            return const Center(
              child: Text(
                'No scores yet.\nSurvive a run to fill the Top 10.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF9AA890)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2218),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: Text(
                    '${index + 1}.',
                    style: const TextStyle(
                      color: Color(0xFF7CFFB2),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  title: Text(
                    '${entry.score}',
                    style: const TextStyle(
                      color: Color(0xFFEDE8D8),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
