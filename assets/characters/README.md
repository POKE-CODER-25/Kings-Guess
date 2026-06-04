King's Guess character asset pipeline

No production character art is committed yet.

Future generated art should use this structure:

- assets/characters/king/king_portrait.png
- assets/characters/queen/queen_portrait.png
- assets/characters/minister/minister_portrait.png
- assets/characters/knight/knight_portrait.png
- assets/characters/soldier/soldier_portrait.png
- assets/characters/police/police_portrait.png
- assets/characters/thief/thief_portrait.png

Recommended source format:

- 1024x1024 PNG
- Transparent background
- Character centered with full body or bust visible
- Leave 8-12% safe padding around the silhouette
- Keep role props as optional separate layers when possible

Optional future layers:

- {role_id}_glow.png
- {role_id}_shadow.png
- {role_id}_prop.png
- {role_id}_foreground_fx.png

Do not add these paths to pubspec.yaml until real files exist.
