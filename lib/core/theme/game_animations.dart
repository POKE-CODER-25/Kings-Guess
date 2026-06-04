import 'package:flutter/material.dart';

class GameAnimations {
  const GameAnimations._();

  static const fast = Duration(milliseconds: 140);
  static const normal = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 520);

  static Widget fadeSlideIn(
    Widget child,
    Animation<double> animation, {
    Offset from = const Offset(0, 0.05),
  }) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: from, end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }

  static Widget popIn(Widget child, Animation<double> animation) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutBack,
    );
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(scale: curved, child: child),
    );
  }

  static double pulse(double value) {
    return 1 + (0.035 * Curves.easeInOut.transform(value));
  }

  static double shake(double value, {double distance = 8}) {
    return distance * (1 - value) * (value % 0.2 < 0.1 ? 1 : -1);
  }

  static double pressScale(bool pressed) => pressed ? 0.96 : 1.0;

  static double glowingBorder(double value) {
    return 0.35 + (0.65 * Curves.easeInOut.transform(value));
  }

  static double slowFloat(double value, {double distance = 8}) {
    return distance * (0.5 - Curves.easeInOut.transform(value));
  }
}
