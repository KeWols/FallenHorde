import 'dart:math';

/// Isolated RNG so procedural generation can be seeded while debugging.
class GameRng {
  GameRng([int? seed]) : _random = seed != null ? Random(seed) : Random();

  Random _random;
  int? _seed;

  int? get seed => _seed;

  void reseed(int? seed) {
    _seed = seed;
    _random = seed != null ? Random(seed) : Random();
  }

  double nextDouble() => _random.nextDouble();

  int nextInt(int max) => max <= 0 ? 0 : _random.nextInt(max);

  bool nextBool() => _random.nextBool();

  double range(double min, double max) => min + nextDouble() * (max - min);

  int rangeInt(int min, int maxInclusive) {
    if (maxInclusive <= min) {
      return min;
    }
    return min + nextInt(maxInclusive - min + 1);
  }

  T pick<T>(List<T> items) => items[nextInt(items.length)];

  T pickWeighted<T>(List<T> items, List<double> weights) {
    assert(items.length == weights.length);
    var total = 0.0;
    for (final w in weights) {
      total += w;
    }
    var roll = nextDouble() * total;
    for (var i = 0; i < items.length; i++) {
      roll -= weights[i];
      if (roll <= 0) {
        return items[i];
      }
    }
    return items.last;
  }
}
