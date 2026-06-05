const bool audioEnabled = false;

class AudioService {
  AudioService._();

  static final AudioService instance = AudioService._();

  // Future AI-generated music and sound effects should be placed in:
  // assets/audio/
  //
  // Planned files:
  // - lobby_theme.mp3
  // - game_theme.mp3
  // - click.mp3
  // - correct_guess.mp3
  // - wrong_guess.mp3
  // - round_start.mp3
  // - round_end.mp3
  // - victory.mp3
  //
  // Audio is intentionally disabled for this foundation phase. While
  // audioEnabled is false, methods return before loading or playing anything.

  Future<void> initialize() async {
    if (!audioEnabled) return;
  }

  Future<void> playClick() async {
    if (!audioEnabled) return;
  }

  Future<void> playCorrectGuess() async {
    if (!audioEnabled) return;
  }

  Future<void> playWrongGuess() async {
    if (!audioEnabled) return;
  }

  Future<void> playRoundStart() async {
    if (!audioEnabled) return;
  }

  Future<void> playRoundEnd() async {
    if (!audioEnabled) return;
  }

  Future<void> playVictory() async {
    if (!audioEnabled) return;
  }

  Future<void> playLobbyTheme() async {
    if (!audioEnabled) return;
  }

  Future<void> playGameTheme() async {
    if (!audioEnabled) return;
  }

  Future<void> stopMusic() async {
    if (!audioEnabled) return;
  }

  Future<void> playCorrect() => playCorrectGuess();

  Future<void> playWrong() => playWrongGuess();

  Future<void> playRoundComplete() => playRoundEnd();

  Future<void> playTimerWarning() async {
    if (!audioEnabled) return;
  }

  Future<void> playLobbyMusic() => playLobbyTheme();

  Future<void> stopLobbyMusic() => stopMusic();

  void setMusicVolume(double value) {
    if (!audioEnabled) return;
  }

  void setSfxVolume(double value) {
    if (!audioEnabled) return;
  }

  void setMusicMuted(bool muted) {
    if (!audioEnabled) return;
  }

  void setSfxMuted(bool muted) {
    if (!audioEnabled) return;
  }
}
