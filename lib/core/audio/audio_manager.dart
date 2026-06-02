import 'package:flutter/services.dart';

class AudioManager {
  void playSound(String key) {
    switch (key) {
      case 'move':
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.selectionClick();
        break;
      case 'lever':
      case 'key':
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.mediumImpact();
        break;
      case 'floor':
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.heavyImpact();
        break;
      case 'enemyMove':
        HapticFeedback.selectionClick();
        break;
      case 'attack':
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.lightImpact();
        break;
      case 'hit':
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.mediumImpact();
        break;
      case 'blocked':
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.heavyImpact();
        break;
      case 'boss':
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.heavyImpact();
        break;
      case 'death':
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.vibrate();
        break;
      default:
        SystemSound.play(SystemSoundType.click);
    }
  }

  void playMusic(String key) {
    // TODO: connect to Flame audio player and loop music.
  }

  void stopMusic() {
    // TODO: stop current background music.
  }
}
