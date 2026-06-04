import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/audio_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase must be initialized before any Auth or Firestore calls are made.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AudioService.instance.initialize();

  runApp(const KingsGuessApp());
}
