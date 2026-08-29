import 'package:flame/components.dart';

import '../components/units/unit_component.dart';
import '../config/game_config.dart';
import '../necromancy_game.dart';

class MovementSystem {
  MovementSystem(this.game);

  final NecromancyGame game;

  void step(double dt) {
    final units = game.world.living;
    for (final unit in units) {
      var desired = unit.desiredVelocity.clone();
      if (desired.length2 > 0) {
        desired.normalize();
      }
      final sep = _separation(unit);
      final speed = unit.effectiveSpeed;
      unit.velocity
        ..setFrom(desired * speed)
        ..add(sep * speed * GameConfig.separationWeight);
      if (unit.velocity.length > speed) {
        unit.velocity.scaleTo(speed);
      }
      unit.position += unit.velocity * dt;
      unit.position.setFrom(WorldBounds.clamp(unit.position, unit.physicalRadius));
    }

    for (var i = 0; i < GameConfig.overlapResolveIterations; i++) {
      _resolveOverlaps(units);
    }
  }

  Vector2 _separation(UnitComponent unit) {
    final neighbors = game.spatial.queryNeighbors(
      unit,
      unit.physicalRadius * 4 + 18,
    );
    final push = Vector2.zero();
    for (final other in neighbors) {
      final delta = unit.position - other.position;
      var dist = delta.length;
      final minDist = unit.physicalRadius + other.physicalRadius + 2;
      if (dist < 0.001) {
        dist = 0.001;
        delta.setValues(1, 0);
      }
      if (dist < minDist * 1.35) {
        final strength = ((minDist * 1.35) - dist) / (minDist * 1.35);
        push.add(delta.normalized() * strength);
      }
    }
    return push;
  }

  void _resolveOverlaps(List<UnitComponent> units) {
    for (final unit in units) {
      final neighbors = game.spatial.queryNeighbors(
        unit,
        unit.physicalRadius + 36,
      );
      for (final other in neighbors) {
        if (other.id <= unit.id) {
          continue;
        }
        final delta = unit.position - other.position;
        var dist = delta.length;
        final minDist = unit.physicalRadius + other.physicalRadius;
        if (dist >= minDist || dist == 0) {
          if (dist == 0) {
            unit.position.add(Vector2(1.5, 0));
          }
          continue;
        }
        final overlap = minDist - dist;
        final n = delta / dist;
        final massA = unit.physicalRadius;
        final massB = other.physicalRadius;
        final total = massA + massB;
        unit.position += n * overlap * (massB / total);
        other.position -= n * overlap * (massA / total);
        unit.position.setFrom(WorldBounds.clamp(unit.position, unit.physicalRadius));
        other.position.setFrom(WorldBounds.clamp(other.position, other.physicalRadius));
      }
    }
  }
}
