import 'audio_service.dart';

class SoundService {
  const SoundService();

  Future<void> playClick() => AudioService.instance.playClick();

  Future<void> playCorrect() => AudioService.instance.playCorrect();

  Future<void> playWrong() => AudioService.instance.playWrong();

  Future<void> playRoundComplete() => AudioService.instance.playRoundComplete();
}
