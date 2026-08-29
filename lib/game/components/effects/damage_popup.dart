import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class DamagePopup extends TextComponent {
  DamagePopup({
    required Vector2 worldPosition,
    required int amount,
  }) : super(
          text: '-$amount',
          position: worldPosition.clone(),
          anchor: Anchor.center,
          priority: 40,
          textRenderer: TextPaint(
            style: const TextStyle(
              color: Color(0xFFFFF2F0),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              shadows: [
                Shadow(color: Color(0xFF8B1010), blurRadius: 6),
                Shadow(color: Color(0xCC000000), blurRadius: 2),
              ],
            ),
          ),
        );

  double _age = 0;
  static const _lifetime = 0.55;
  late final Vector2 _origin;

  @override
  Future<void> onLoad() async {
    _origin = position.clone();
  }

  @override
  void update(double dt) {
    _age += dt;
    final t = (_age / _lifetime).clamp(0.0, 1.0);
    position = Vector2(_origin.x, _origin.y - 22 * Curves.easeOutCubic.transform(t));
    final fade = t < 0.55 ? 1.0 : 1 - ((t - 0.55) / 0.45);
    textRenderer = TextPaint(
      style: TextStyle(
        color: Color.fromARGB((255 * fade).round().clamp(0, 255), 255, 242, 240),
        fontSize: 13 + 3 * (1 - t),
        fontWeight: FontWeight.w800,
        shadows: const [
          Shadow(color: Color(0xFF8B1010), blurRadius: 6),
        ],
      ),
    );
    if (_age >= _lifetime) {
      removeFromParent();
    }
  }
}
