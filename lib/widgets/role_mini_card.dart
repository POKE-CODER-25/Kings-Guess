import 'package:flutter/material.dart';

import '../core/theme/game_colors.dart';
import '../features/game/data/role_data.dart';

class RoleMiniCard extends StatelessWidget {
  const RoleMiniCard({super.key, required this.roleName, this.compact = false});

  final String roleName;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final role = RoleCatalog.byName(roleName);
    return Container(
      constraints: const BoxConstraints(minWidth: 0),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 11,
        vertical: compact ? 7 : 9,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            role.secondaryColor.withValues(alpha: 0.92),
            GameColors.parchmentLight,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: role.glowColor.withValues(alpha: 0.75),
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33351A10),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            role.placeholderEmoji,
            style: TextStyle(fontSize: compact ? 20 : 24),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              role.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: role.primaryColor,
                fontSize: compact ? 13 : 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
