import 'package:flame/components.dart';

import '../components/units/unit_component.dart';

/// Uniform grid for neighborhood queries. Avoids all-vs-all distance checks.
class SpatialGrid {
  SpatialGrid({this.cellSize = 96});

  final double cellSize;
  final Map<int, List<UnitComponent>> _cells = {};
  final List<List<UnitComponent>> _pool = [];

  void clear() {
    for (final list in _cells.values) {
      list.clear();
      _pool.add(list);
    }
    _cells.clear();
  }

  void insert(UnitComponent unit) {
    if (!unit.isAlive) {
      return;
    }
    final key = _key(unit.position);
    _cells.putIfAbsent(key, _obtain).add(unit);
  }

  List<UnitComponent> queryRadius(Vector2 position, double radius) {
    final results = <UnitComponent>[];
    final minX = ((position.x - radius) / cellSize).floor();
    final maxX = ((position.x + radius) / cellSize).floor();
    final minY = ((position.y - radius) / cellSize).floor();
    final maxY = ((position.y + radius) / cellSize).floor();
    final radius2 = radius * radius;
    for (var gx = minX; gx <= maxX; gx++) {
      for (var gy = minY; gy <= maxY; gy++) {
        final bucket = _cells[_pack(gx, gy)];
        if (bucket == null) {
          continue;
        }
        for (final unit in bucket) {
          if (!unit.isAlive) {
            continue;
          }
          if (unit.position.distanceToSquared(position) <= radius2) {
            results.add(unit);
          }
        }
      }
    }
    return results;
  }

  List<UnitComponent> queryNeighbors(UnitComponent unit, double radius) {
    final nearby = queryRadius(unit.position, radius);
    nearby.remove(unit);
    return nearby;
  }

  int _key(Vector2 position) {
    return _pack(
      (position.x / cellSize).floor(),
      (position.y / cellSize).floor(),
    );
  }

  int _pack(int x, int y) => (x * 73856093) ^ (y * 19349663);

  List<UnitComponent> _obtain() {
    if (_pool.isEmpty) {
      return <UnitComponent>[];
    }
    return _pool.removeLast();
  }
}
