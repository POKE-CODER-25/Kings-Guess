import 'package:flutter/material.dart';

import '../core/theme/game_colors.dart';
import '../core/theme/game_gradients.dart';
import '../core/theme/game_shadows.dart';
import '../services/audio_service.dart';
import 'pressable_scale.dart';

enum GameButtonStyle { primary, secondary, danger, success }

class GameButton extends StatefulWidget {
  const GameButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.style = GameButtonStyle.primary,
    this.playClickSound = true,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final GameButtonStyle style;
  final bool playClickSound;
  final bool expand;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.isLoading && widget.onPressed != null;
    final palette = _palette(widget.style, enabled);
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 145),
      curve: Curves.easeOutBack,
      height: 58,
      width: widget.expand ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
      decoration: BoxDecoration(
        gradient: palette.gradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border, width: 2.5),
        boxShadow: _pressed
            ? GameShadows.buttonPressed
            : [
                ...GameShadows.button,
                BoxShadow(
                  color: palette.border.withValues(alpha: 0.22),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              opacity: _pressed ? 0.45 : 0.18,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const RadialGradient(
                    center: Alignment.topCenter,
                    radius: 0.95,
                    colors: [Color(0x99FFFFFF), Color(0x00FFFFFF)],
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Row(
              mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.isLoading)
                  const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                else if (widget.icon != null)
                  Icon(widget.icon, color: palette.foreground, size: 23),
                if (widget.isLoading || widget.icon != null)
                  const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.foreground,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      shadows: const [
                        Shadow(color: Color(0x66351A10), offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return PressableScale(
      enabled: enabled,
      onPressedChanged: (pressed) => setState(() => _pressed = pressed),
      onPressed: enabled
          ? () {
              if (widget.playClickSound) AudioService.instance.playClick();
              widget.onPressed?.call();
            }
          : null,
      child: Opacity(opacity: enabled ? 1 : 0.64, child: content),
    );
  }
}

class _ButtonPalette {
  const _ButtonPalette({
    required this.gradient,
    required this.border,
    required this.foreground,
  });

  final Gradient gradient;
  final Color border;
  final Color foreground;
}

_ButtonPalette _palette(GameButtonStyle style, bool enabled) {
  if (!enabled) {
    return const _ButtonPalette(
      gradient: LinearGradient(
        colors: [Color(0xFFD3C5AA), GameColors.disabled],
      ),
      border: Color(0xFFE8D9B8),
      foreground: Colors.white,
    );
  }

  return switch (style) {
    GameButtonStyle.primary => const _ButtonPalette(
      gradient: GameGradients.goldButton,
      border: Color(0xFFFFE7A0),
      foreground: GameColors.woodDark,
    ),
    GameButtonStyle.secondary => const _ButtonPalette(
      gradient: GameGradients.blueButton,
      border: Color(0xFF8DA7FF),
      foreground: Colors.white,
    ),
    GameButtonStyle.danger => const _ButtonPalette(
      gradient: GameGradients.redButton,
      border: Color(0xFFFFA4A4),
      foreground: Colors.white,
    ),
    GameButtonStyle.success => const _ButtonPalette(
      gradient: GameGradients.greenButton,
      border: Color(0xFFBDF1C9),
      foreground: Colors.white,
    ),
  };
}
