import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config/game_config.dart';

class ArmyJoystick extends JoystickComponent {
  ArmyJoystick()
      : super(
          knob: CircleComponent(
            radius: 18,
            paint: Paint()
              ..color = Colors.white.withValues(
                alpha: GameConfig.joystickKnobOpacity,
              ),
          ),
          background: CircleComponent(
            radius: 52,
            paint: Paint()
              ..color = Colors.white.withValues(
                alpha: GameConfig.joystickOpacity,
              ),
          ),
          margin: const EdgeInsets.only(left: 28, bottom: 28),
          priority: 1000,
        );
}
