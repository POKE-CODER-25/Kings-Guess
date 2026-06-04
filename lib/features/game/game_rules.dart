class RoleRule {
  const RoleRule({required this.name, required this.score});

  final String name;
  final int score;
}

class GameRules {
  static const turnSeconds = 120;

  static const _rulesByPlayerCount = <int, List<RoleRule>>{
    5: [
      RoleRule(name: 'King', score: 1000),
      RoleRule(name: 'Queen', score: 800),
      RoleRule(name: 'Minister', score: 500),
      RoleRule(name: 'Police', score: 250),
      RoleRule(name: 'Thief', score: 0),
    ],
    6: [
      RoleRule(name: 'King', score: 1000),
      RoleRule(name: 'Queen', score: 800),
      RoleRule(name: 'Minister', score: 600),
      RoleRule(name: 'Knight', score: 400),
      RoleRule(name: 'Police', score: 200),
      RoleRule(name: 'Thief', score: 0),
    ],
    7: [
      RoleRule(name: 'King', score: 1000),
      RoleRule(name: 'Queen', score: 800),
      RoleRule(name: 'Minister', score: 600),
      RoleRule(name: 'Knight', score: 400),
      RoleRule(name: 'Soldier', score: 250),
      RoleRule(name: 'Police', score: 100),
      RoleRule(name: 'Thief', score: 0),
    ],
  };

  static List<RoleRule> rolesForCount(int playerCount) {
    final roles = _rulesByPlayerCount[playerCount];
    if (roles == null) {
      throw ArgumentError('Player count must be 5, 6, or 7');
    }
    return roles;
  }

  static int scoreForRole(String role, int playerCount) {
    return rolesForCount(
      playerCount,
    ).firstWhere((rule) => rule.name == role).score;
  }

  static String firstTargetRole(int playerCount) {
    return rolesForCount(playerCount)[1].name;
  }

  static bool isFinalRole(String role, int playerCount) {
    return rolesForCount(playerCount).last.name == role;
  }

  static String nextTargetRole({
    required int playerCount,
    required int currentRoleIndex,
  }) {
    return rolesForCount(playerCount)[currentRoleIndex + 2].name;
  }
}
