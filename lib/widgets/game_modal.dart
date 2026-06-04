import 'package:flutter/material.dart';

import '../core/theme/game_text_styles.dart';
import 'game_button.dart';
import 'game_panel.dart';

class GameModal extends StatelessWidget {
  const GameModal({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.onConfirm,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(22),
      child: GamePanel(
        variant: GamePanelVariant.compact,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: GameTextStyles.screenTitle,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GameTextStyles.body,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: GameButton(
                    label: cancelLabel,
                    style: GameButtonStyle.secondary,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GameButton(
                    label: confirmLabel,
                    style: GameButtonStyle.primary,
                    onPressed:
                        onConfirm ?? () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
