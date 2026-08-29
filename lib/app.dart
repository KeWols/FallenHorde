import 'package:flutter/material.dart';

import 'game/screens/main_menu_screen.dart';

class FallenHordeApp extends StatelessWidget {
  const FallenHordeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fallen Horde',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2BB673),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF12160F),
        useMaterial3: true,
      ),
      home: const MainMenuScreen(),
    );
  }
}
