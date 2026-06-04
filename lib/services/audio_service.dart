import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AudioService {
  AudioService._();

  static final AudioService instance = AudioService._();

  // TODO: Replace placeholder assets with real game audio later.
  bool audioEnabled = false;
  double musicVolume = 0.55;
  double sfxVolume = 0.75;
  bool isMusicMuted = false;
  bool isSfxMuted = false;

  bool _initialized = false;
  bool _lobbyMusicPlaying = false;
  final Set<String> _availableAssets = {};
  final Set<String> _missingAssetsLogged = {};
  final Set<String> _errorsLogged = {};

  Future<void> initialize() async {
    if (!audioEnabled || _initialized) return;

    try {
      FlameAudio.bgm.initialize();
      _initialized = true;
    } catch (error, stackTrace) {
      _logAudioErrorOnce('initialize', error, stackTrace);
    }
  }

  void setMusicVolume(double value) {
    musicVolume = value.clamp(0.0, 1.0);
  }

  void setSfxVolume(double value) {
    sfxVolume = value.clamp(0.0, 1.0);
  }

  void setMusicMuted(bool muted) {
    isMusicMuted = muted;
    if (muted) {
      stopLobbyMusic();
    }
  }

  void setSfxMuted(bool muted) {
    isSfxMuted = muted;
  }

  Future<void> playClick() => _playSfx('click.mp3');

  Future<void> playCorrect() => _playSfx('correct.mp3');

  Future<void> playWrong() => _playSfx('wrong.mp3');

  Future<void> playRoundStart() => _playSfx('round_start.mp3');

  Future<void> playRoundComplete() => _playSfx('round_complete.mp3');

  Future<void> playTimerWarning() => _playSfx('timer_warning.mp3');

  Future<void> playVictory() => _playSfx('victory.mp3');

  Future<void> playLobbyMusic() async {
    if (!audioEnabled) return;
    await initialize();
    if (isMusicMuted || _effectiveMusicVolume <= 0 || _lobbyMusicPlaying) {
      return;
    }
    if (!await _assetExists('lobby_theme.mp3')) return;

    try {
      await FlameAudio.bgm.play(
        'lobby_theme.mp3',
        volume: _effectiveMusicVolume,
      );
      _lobbyMusicPlaying = true;
    } catch (error, stackTrace) {
      _lobbyMusicPlaying = false;
      _logAudioErrorOnce('playLobbyMusic', error, stackTrace);
    }
  }

  Future<void> stopLobbyMusic() async {
    if (!audioEnabled || (!_initialized && !_lobbyMusicPlaying)) return;

    try {
      await FlameAudio.bgm.stop();
    } catch (error, stackTrace) {
      _logAudioErrorOnce('stopLobbyMusic', error, stackTrace);
    } finally {
      _lobbyMusicPlaying = false;
    }
  }

  Future<void> _playSfx(String fileName) async {
    if (!audioEnabled) return;
    await initialize();
    if (isSfxMuted || _effectiveSfxVolume <= 0) return;
    if (!await _assetExists(fileName)) return;

    try {
      await FlameAudio.play(fileName, volume: _effectiveSfxVolume);
    } catch (error, stackTrace) {
      _logAudioErrorOnce('playSfx:$fileName', error, stackTrace);
    }
  }

  double get _effectiveMusicVolume => isMusicMuted ? 0 : musicVolume;

  double get _effectiveSfxVolume => isSfxMuted ? 0 : sfxVolume;

  Future<bool> _assetExists(String fileName) async {
    if (_availableAssets.contains(fileName)) return true;

    try {
      await rootBundle.load('assets/audio/$fileName');
      _availableAssets.add(fileName);
      return true;
    } on FlutterError {
      _logMissingAsset(fileName);
      return false;
    } catch (error, stackTrace) {
      _logAudioErrorOnce('assetCheck:$fileName', error, stackTrace);
      return false;
    }
  }

  void _logMissingAsset(String fileName) {
    if (_missingAssetsLogged.add(fileName)) {
      debugPrint('Audio asset missing: $fileName');
    }
  }

  void _logAudioErrorOnce(String action, Object error, StackTrace stackTrace) {
    if (!_errorsLogged.add(action)) return;

    debugPrint('AudioService $action failed: $error');
    if (kDebugMode) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
