import 'package:flutter/material.dart';

import '../core/theme/game_colors.dart';
import '../core/theme/game_text_styles.dart';

class GameTextField extends StatelessWidget {
  const GameTextField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final int? maxLength;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      style: GameTextStyles.body.copyWith(fontWeight: FontWeight.w900),
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        prefixIcon: icon == null ? null : Icon(icon, color: GameColors.ruby),
        filled: true,
        fillColor: GameColors.parchmentLight,
        labelStyle: GameTextStyles.smallLabel,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(
            color: GameColors.parchmentDeep,
            width: 2.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: GameColors.palaceGold, width: 3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: GameColors.ruby, width: 2.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: GameColors.ruby, width: 3),
        ),
      ),
    );
  }
}

class GameErrorBanner extends StatelessWidget {
  const GameErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE5DC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GameColors.ruby, width: 2),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_rounded, color: GameColors.ruby),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: GameTextStyles.danger)),
        ],
      ),
    );
  }
}

class WaitingDots extends StatefulWidget {
  const WaitingDots({super.key, this.color = GameColors.ruby});

  final Color color;

  @override
  State<WaitingDots> createState() => _WaitingDotsState();
}

class _WaitingDotsState extends State<WaitingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final active = (_controller.value * 3).floor();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedScale(
                scale: index == active ? 1.35 : 0.85,
                duration: const Duration(milliseconds: 180),
                child: CircleAvatar(radius: 4, backgroundColor: widget.color),
              ),
            );
          }),
        );
      },
    );
  }
}
