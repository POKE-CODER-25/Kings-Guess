import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/audio_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('UNCAUGHT PLATFORM ERROR: $error');
    debugPrint('$stack');
    return false;
  };

  // Firebase must be initialized before any Auth or Firestore calls are made.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AudioService.instance.initialize();

  runApp(const KingsGuessApp());
}
