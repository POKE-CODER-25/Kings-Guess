import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/game_colors.dart';
import '../core/theme/game_shadows.dart';

enum GameToastKind { success, error, event }

enum GameToastHaptic { none, light, medium, success, warning }

class GameToastController {
  GameToastController._();

  static void show(
    BuildContext context, {
    required String message,
    required GameToastKind kind,
    IconData? icon,
    Duration duration = const Duration(milliseconds: 2400),
    GameToastHaptic haptic = GameToastHaptic.light,
  }) {
    if (!context.mounted) return;
    _performHaptic(haptic);

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: FloatingNotificationBanner(
            message: message,
            kind: kind,
            icon: icon,
          ),
          duration: duration,
          behavior: SnackBarBehavior.floating,
          elevation: 0,
          backgroundColor: Colors.transparent,
          padding: EdgeInsets.zero,
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          dismissDirection: DismissDirection.horizontal,
        ),
      );
  }

  static void _performHaptic(GameToastHaptic haptic) {
    switch (haptic) {
      case GameToastHaptic.none:
        return;
      case GameToastHaptic.light:
      case GameToastHaptic.success:
        HapticFeedback.lightImpact();
        return;
      case GameToastHaptic.medium:
      case GameToastHaptic.warning:
        HapticFeedback.mediumImpact();
        return;
    }
  }
}

void showSuccessToast(
  BuildContext context,
  String message, {
  IconData icon = Icons.check_circle_rounded,
}) {
  GameToastController.show(
    context,
    message: message,
    kind: GameToastKind.success,
    icon: icon,
    haptic: GameToastHaptic.success,
  );
}

void showErrorToast(
  BuildContext context,
  String message, {
  IconData icon = Icons.error_rounded,
}) {
  GameToastController.show(
    context,
    message: message,
    kind: GameToastKind.error,
    icon: icon,
    duration: const Duration(milliseconds: 3000),
    haptic: GameToastHaptic.warning,
  );
}

void showGameEventToast(
  BuildContext context,
  String message, {
  IconData icon = Icons.auto_awesome_rounded,
}) {
  GameToastController.show(
    context,
    message: message,
    kind: GameToastKind.event,
    icon: icon,
    haptic: GameToastHaptic.light,
  );
}

class FloatingNotificationBanner extends StatelessWidget {
  const FloatingNotificationBanner({
    super.key,
    required this.message,
    required this.kind,
    this.icon,
  });

  final String message;
  final GameToastKind kind;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = _toastColors(kind);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.background,
              colors.background.withValues(alpha: 0.92),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: colors.border, width: 2.5),
          boxShadow: GameShadows.panel,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.iconBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon ?? Icons.auto_awesome_rounded,
                color: colors.icon,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: GameColors.woodDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToastColors {
  const _ToastColors({
    required this.background,
    required this.border,
    required this.iconBackground,
    required this.icon,
  });

  final Color background;
  final Color border;
  final Color iconBackground;
  final Color icon;
}

_ToastColors _toastColors(GameToastKind kind) {
  return switch (kind) {
    GameToastKind.success => const _ToastColors(
      background: GameColors.parchment,
      border: GameColors.palaceGold,
      iconBackground: Color(0xFFEAF6D5),
      icon: GameColors.emerald,
    ),
    GameToastKind.error => const _ToastColors(
      background: Color(0xFFFFE5DC),
      border: GameColors.ruby,
      iconBackground: Color(0xFFFFD0C3),
      icon: GameColors.ruby,
    ),
    GameToastKind.event => const _ToastColors(
      background: GameColors.parchmentLight,
      border: GameColors.palaceGold,
      iconBackground: GameColors.candle,
      icon: GameColors.ruby,
    ),
  };
}
