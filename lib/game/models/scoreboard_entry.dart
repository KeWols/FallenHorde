class ScoreboardEntry {
  const ScoreboardEntry({
    required this.score,
    required this.achievedAtMs,
  });

  final int score;
  final int achievedAtMs;

  Map<String, Object> toJson() => {
        'score': score,
        'achievedAtMs': achievedAtMs,
      };

  factory ScoreboardEntry.fromJson(Map<String, dynamic> json) {
    return ScoreboardEntry(
      score: (json['score'] as num?)?.toInt() ?? 0,
      achievedAtMs: (json['achievedAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}
