import 'package:flutter/material.dart';

import 'game_button.dart';

class RoyalButton extends StatelessWidget {
  const RoyalButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isSecondary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isSecondary;

  @override
  Widget build(BuildContext context) {
    return GameButton(
      label: label,
      icon: icon,
      isLoading: isLoading,
      style: isSecondary ? GameButtonStyle.secondary : GameButtonStyle.primary,
      onPressed: onPressed,
    );
  }
}
