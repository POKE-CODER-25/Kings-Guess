import 'package:flutter/material.dart';

void safeNavigateReplacement(
  BuildContext context,
  Widget page,
  String reason, {
  bool clearStack = false,
}) {
  if (!context.mounted) return;
  debugPrint('NAVIGATE: $reason');
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    final navigator = Navigator.maybeOf(context);
    if (navigator == null) return;
    if (clearStack) {
      navigator.pushAndRemoveUntil(royalRoute(page), (_) => false);
    } else {
      navigator.pushReplacement(royalRoute(page));
    }
  });
}

Route<T> royalRoute<T>(Widget screen) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, _, _) => screen,
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (_, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      final outgoing = CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: Tween(begin: 0.0, end: 1.0).animate(curved),
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(curved),
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.055),
              end: Offset.zero,
            ).animate(curved),
            child: Transform.scale(
              scale: 1 - (outgoing.value * 0.025),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}
