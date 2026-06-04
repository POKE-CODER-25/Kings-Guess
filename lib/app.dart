import 'package:flutter/material.dart';

import 'core/theme/game_colors.dart';
import 'core/theme/game_text_styles.dart';
import 'features/auth/auth_gate.dart';

class KingsGuessApp extends StatelessWidget {
  const KingsGuessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "King's Guess",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: GameColors.parchment,
        colorScheme: ColorScheme.fromSeed(
          seedColor: GameColors.palaceGold,
          primary: GameColors.palaceGold,
          secondary: GameColors.ruby,
          tertiary: GameColors.royalBlue,
          surface: GameColors.parchmentLight,
          error: GameColors.ruby,
        ),
        fontFamily: 'Roboto',
        textTheme: ThemeData.light().textTheme
            .apply(bodyColor: GameColors.ink, displayColor: GameColors.ink)
            .copyWith(
              displaySmall: GameTextStyles.giantTitle,
              headlineMedium: GameTextStyles.screenTitle,
              headlineSmall: GameTextStyles.screenTitle,
              titleMedium: GameTextStyles.sectionTitle,
              bodyMedium: GameTextStyles.body,
              labelSmall: GameTextStyles.smallLabel,
            ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: GameColors.parchmentLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: GameColors.parchmentDeep,
              width: 2,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: GameColors.parchmentDeep,
              width: 2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: GameColors.palaceGold,
              width: 3,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: GameColors.ruby, width: 2),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}
