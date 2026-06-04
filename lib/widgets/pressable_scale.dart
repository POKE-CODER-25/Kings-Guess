import 'package:flutter/material.dart';

import '../config/polish_config.dart';

class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.onPressed,
    this.pressedScale = 0.96,
    this.hoverScale = 1.0,
    this.onPressedChanged,
  });

  final Widget child;
  final bool enabled;
  final VoidCallback? onPressed;
  final double pressedScale;
  final double hoverScale;
  final ValueChanged<bool>? onPressedChanged;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
    widget.onPressedChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    if (disablePolishForDebug) {
      return GestureDetector(
        onTap: widget.enabled ? widget.onPressed : null,
        child: widget.child,
      );
    }

    final scale = _pressed ? widget.pressedScale : 1.0;

    return Listener(
      onPointerDown: widget.enabled ? (_) => _setPressed(true) : null,
      onPointerUp: widget.enabled
          ? (_) {
              _setPressed(false);
              widget.onPressed?.call();
            }
          : null,
      onPointerCancel: widget.enabled ? (_) => _setPressed(false) : null,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 115),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
