import 'package:flutter/material.dart';

void safeNavigateReplacement(
  BuildContext context,
  Widget page,
  String reason, {
  bool clearStack = false,
}) {
  if (!context.mounted) return;
  debugPrint('NAVIGATE: $reason');
  final navigator = Navigator.maybeOf(context);
  if (navigator == null) return;
  if (clearStack) {
    navigator.pushAndRemoveUntil(royalRoute(page), (_) => false);
  } else {
    navigator.pushReplacement(royalRoute(page));
  }
}

Future<void> safeManualGoHome(
  BuildContext context, {
  required Widget homeScreen,
  String reason = '',
}) async {
  await Future<void>.delayed(Duration.zero);
  if (!context.mounted) return;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    debugPrint('NAVIGATE: $reason');
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => homeScreen),
      (route) => false,
    );
  });
}

Route<T> royalRoute<T>(Widget screen) {
  return MaterialPageRoute<T>(builder: (_) => screen);
}
