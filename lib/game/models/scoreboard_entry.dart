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
      score: json['score'] as int? ?? 0,
      achievedAtMs: json['achievedAtMs'] as int? ?? 0,
    );
  }
}
