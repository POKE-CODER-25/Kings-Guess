import 'package:flutter/material.dart';

import '../features/game/data/role_data.dart';

class RoleVisuals {
  static String emojiFor(String role) {
    return RoleCatalog.byName(role).placeholderEmoji;
  }

  static Color colorFor(String role) {
    return RoleCatalog.byName(role).primaryColor;
  }
}
