import 'package:flutter/material.dart';

enum RoleRarityLevel { common, uncommon, rare, epic, legendary }

enum RoleEntranceAnimationType {
  royalRise,
  veilFade,
  scrollUnfurl,
  shieldClash,
  marchingPulse,
  spotlightScan,
  shadowSlip,
}

class RoleData {
  const RoleData({
    required this.id,
    required this.displayName,
    required this.shortFlavorText,
    required this.longLoreDescription,
    required this.rarityLevel,
    required this.glowColor,
    required this.primaryColor,
    required this.secondaryColor,
    required this.placeholderEmoji,
    required this.roleImportance,
    required this.futureAssetKey,
    required this.entranceAnimationType,
  });

  final String id;
  final String displayName;
  final String shortFlavorText;
  final String longLoreDescription;
  final RoleRarityLevel rarityLevel;
  final Color glowColor;
  final Color primaryColor;
  final Color secondaryColor;
  final String placeholderEmoji;
  final int roleImportance;
  final String futureAssetKey;
  final RoleEntranceAnimationType entranceAnimationType;

  int get rarityStars => switch (rarityLevel) {
    RoleRarityLevel.common => 1,
    RoleRarityLevel.uncommon => 2,
    RoleRarityLevel.rare => 3,
    RoleRarityLevel.epic => 4,
    RoleRarityLevel.legendary => 5,
  };
}

class RoleCatalog {
  const RoleCatalog._();

  static const unknown = RoleData(
    id: 'unknown',
    displayName: 'Hidden Role',
    shortFlavorText: 'The court keeps its secret.',
    longLoreDescription:
        'A sealed court card waits for the reveal. No hidden role is shown until the player is allowed to see it.',
    rarityLevel: RoleRarityLevel.common,
    glowColor: Color(0xFFE5B540),
    primaryColor: Color(0xFF23325F),
    secondaryColor: Color(0xFFFFE6A0),
    placeholderEmoji: '\u{1F0CF}',
    roleImportance: 0,
    futureAssetKey: 'assets/characters/unknown/unknown_portrait.png',
    entranceAnimationType: RoleEntranceAnimationType.veilFade,
  );

  static const roles = <RoleData>[
    RoleData(
      id: 'king',
      displayName: 'King',
      shortFlavorText: 'Rule the court. Find the Queen.',
      longLoreDescription:
          'A dramatic ruler with a strategic eye. The King commands attention, reads the room, and turns suspicion into power.',
      rarityLevel: RoleRarityLevel.legendary,
      glowColor: Color(0xFFFFD35A),
      primaryColor: Color(0xFF9F6B16),
      secondaryColor: Color(0xFFFFE6A0),
      placeholderEmoji: '\u{1F451}',
      roleImportance: 7,
      futureAssetKey: 'assets/characters/king/king_portrait.png',
      entranceAnimationType: RoleEntranceAnimationType.royalRise,
    ),
    RoleData(
      id: 'queen',
      displayName: 'Queen',
      shortFlavorText: 'Grace under suspicion.',
      longLoreDescription:
          'Elegant, mysterious, and sharply intelligent. The Queen survives through poise, misdirection, and quiet command.',
      rarityLevel: RoleRarityLevel.epic,
      glowColor: Color(0xFFFF8DC8),
      primaryColor: Color(0xFFB83A78),
      secondaryColor: Color(0xFFFFE0F1),
      placeholderEmoji: '\u{1F478}',
      roleImportance: 6,
      futureAssetKey: 'assets/characters/queen/queen_portrait.png',
      entranceAnimationType: RoleEntranceAnimationType.veilFade,
    ),
    RoleData(
      id: 'minister',
      displayName: 'Minister',
      shortFlavorText: 'Whisper strategy into power.',
      longLoreDescription:
          'Wise, calculating, and political. The Minister watches every alliance and turns small details into leverage.',
      rarityLevel: RoleRarityLevel.rare,
      glowColor: Color(0xFFC58A4A),
      primaryColor: Color(0xFF7E4F2B),
      secondaryColor: Color(0xFFFFE6A0),
      placeholderEmoji: '\u{1F4DC}',
      roleImportance: 5,
      futureAssetKey: 'assets/characters/minister/minister_portrait.png',
      entranceAnimationType: RoleEntranceAnimationType.scrollUnfurl,
    ),
    RoleData(
      id: 'knight',
      displayName: 'Knight',
      shortFlavorText: 'Stand firm when the court turns.',
      longLoreDescription:
          'Loyal, honorable, and battle-ready. The Knight brings steel nerves to a room full of whispers.',
      rarityLevel: RoleRarityLevel.rare,
      glowColor: Color(0xFF8DB3E8),
      primaryColor: Color(0xFF4E6E8E),
      secondaryColor: Color(0xFFD7E6F8),
      placeholderEmoji: '\u{1F6E1}\u{FE0F}',
      roleImportance: 4,
      futureAssetKey: 'assets/characters/knight/knight_portrait.png',
      entranceAnimationType: RoleEntranceAnimationType.shieldClash,
    ),
    RoleData(
      id: 'soldier',
      displayName: 'Soldier',
      shortFlavorText: 'Hold the line in silence.',
      longLoreDescription:
          'Disciplined and fearless. The Soldier stands steady under pressure and does not flinch when accused.',
      rarityLevel: RoleRarityLevel.uncommon,
      glowColor: Color(0xFFA4C76D),
      primaryColor: Color(0xFF5E7D45),
      secondaryColor: Color(0xFFE4F0C4),
      placeholderEmoji: '\u{2694}\u{FE0F}',
      roleImportance: 3,
      futureAssetKey: 'assets/characters/soldier/soldier_portrait.png',
      entranceAnimationType: RoleEntranceAnimationType.marchingPulse,
    ),
    RoleData(
      id: 'police',
      displayName: 'Police',
      shortFlavorText: 'Protect order. Watch every move.',
      longLoreDescription:
          'An investigator with tense instincts and suspicious eyes. Police energy is sharp, watchful, and hard to fool.',
      rarityLevel: RoleRarityLevel.uncommon,
      glowColor: Color(0xFF6FA7FF),
      primaryColor: Color(0xFF365D91),
      secondaryColor: Color(0xFFDCEAFF),
      placeholderEmoji: '\u{1F575}\u{FE0F}',
      roleImportance: 2,
      futureAssetKey: 'assets/characters/police/police_portrait.png',
      entranceAnimationType: RoleEntranceAnimationType.spotlightScan,
    ),
    RoleData(
      id: 'thief',
      displayName: 'Thief',
      shortFlavorText: 'Stay hidden until the end.',
      longLoreDescription:
          'Chaotic, sneaky, and unpredictable. The Thief thrives in confusion, vanishes into suspicion, and smiles at danger.',
      rarityLevel: RoleRarityLevel.common,
      glowColor: Color(0xFF8A6A55),
      primaryColor: Color(0xFF4C2B20),
      secondaryColor: Color(0xFFC8A58A),
      placeholderEmoji: '\u{1F5E1}\u{FE0F}',
      roleImportance: 1,
      futureAssetKey: 'assets/characters/thief/thief_portrait.png',
      entranceAnimationType: RoleEntranceAnimationType.shadowSlip,
    ),
  ];

  static RoleData byName(String? roleName) {
    final normalized = (roleName ?? '').trim().toLowerCase();
    if (normalized.isEmpty) return unknown;
    for (final role in roles) {
      if (role.displayName.toLowerCase() == normalized ||
          role.id == normalized) {
        return role;
      }
    }
    return unknown;
  }
}

// TODO: Replace placeholder silhouettes with generated PNG character art later.
// Recommended pipeline:
// - Store final art in assets/characters/{role_id}/{role_id}_portrait.png.
// - Use 1024x1024 source PNGs with transparent backgrounds for clean card framing.
// - Keep optional layers beside portraits, for example:
//   assets/characters/king/king_glow.png
//   assets/characters/king/king_prop_crown.png
//   assets/characters/king/king_shadow.png
// - Register asset folders in pubspec.yaml once real files exist.
// - Keep futureAssetKey values stable so UI code does not change when art lands.
