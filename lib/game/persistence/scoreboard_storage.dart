import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/scoreboard_entry.dart';

class ScoreboardStorage {
  static const _key = 'fallen_horde_top10';
  static const int maxEntries = 10;

  Future<List<ScoreboardEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return [];
    }
    return decoded
        .whereType<Map>()
        .map((e) => ScoreboardEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
  }

  Future<List<ScoreboardEntry>> maybeInsert(int maxScore) async {
    final score = maxScore < 0 ? 0 : maxScore;
    final entries = List<ScoreboardEntry>.from(await load());
    final qualifies = entries.length < maxEntries ||
        (entries.isNotEmpty && score >= entries.last.score);
    if (!qualifies) {
      return entries;
    }
    entries.add(
      ScoreboardEntry(
        score: score,
        achievedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    entries.sort((a, b) => b.score.compareTo(a.score));
    final trimmed = entries.take(maxEntries).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(trimmed.map((e) => e.toJson()).toList()),
    );
    return trimmed;
  }
}
