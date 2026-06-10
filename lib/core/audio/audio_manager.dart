import 'package:flutter/services.dart';
import 'package:flame_audio/flame_audio.dart';

class AudioManager {
  double bgmVolume = 0.4;
  double sfxVolume = 0.6;
  bool isMuted = false;

  final Map<String, AudioPool> _pools = {};

  Future<void> initialize() async {
    // Initialize BGM
    await FlameAudio.bgm.initialize();
    
    // Create AudioPools for frequently used SFX to reduce latency
    final sfxToPool = [
      'move', 'attack', 'hit', 'blocked', 'enemyMove'
    ];

    for (final key in sfxToPool) {
      _pools[key] = await FlameAudio.createPool(
        _getPathForKey(key),
        minPlayers: 3,
        maxPlayers: 5,
      );
    }

    // Preload remaining sounds in cache
    await FlameAudio.audioCache.loadAll([
      'sfx/lever.wav',
      'sfx/floor.wav',
      'sfx/boss.wav',
      'sfx/death.wav',
      'sfx/key.wav',
    ]);
  }

  String _getPathForKey(String key) {
    switch (key) {
      case 'move': return 'sfx/move.wav';
      case 'enemyMove': return 'sfx/enemy_move.wav';
      case 'attack': return 'sfx/attack.wav';
      case 'hit': return 'sfx/hit.wav';
      case 'blocked': return 'sfx/blocked.wav';
      case 'lever': return 'sfx/lever.wav';
      case 'key': return 'sfx/key.wav';
      case 'floor': return 'sfx/floor.wav';
      case 'boss': return 'sfx/boss.wav';
      case 'death': return 'sfx/death.wav';
      default: return 'sfx/move.wav';
    }
  }

  void playSound(String key) {
    if (isMuted) return;

    // Trigger haptics
    _triggerHaptics(key);

    // Play sound from pool if available, otherwise use FlameAudio.play
    if (_pools.containsKey(key)) {
      _pools[key]!.start(volume: sfxVolume);
    } else {
      FlameAudio.play(_getPathForKey(key), volume: sfxVolume);
    }
  }

  void _triggerHaptics(String key) {
    switch (key) {
      case 'move':
      case 'enemyMove':
        HapticFeedback.selectionClick();
        break;
      case 'lever':
      case 'key':
      case 'hit':
        HapticFeedback.mediumImpact();
        break;
      case 'floor':
      case 'blocked':
      case 'boss':
        HapticFeedback.heavyImpact();
        break;
      case 'attack':
        HapticFeedback.lightImpact();
        break;
      case 'death':
        HapticFeedback.vibrate();
        break;
    }
  }

  void playMusic(String key) {
    if (isMuted) return;
    FlameAudio.bgm.play('music/$key.mp3', volume: bgmVolume);
  }

  void stopMusic() {
    FlameAudio.bgm.stop();
  }

  void toggleMute() {
    isMuted = !isMuted;
    if (isMuted) {
      stopMusic();
    } else {
      playMusic('main');
    }
  }

  void setVolume(double volume) {
    sfxVolume = volume;
    bgmVolume = volume * 0.7; // Keep music slightly quieter
    if (!isMuted) {
      FlameAudio.bgm.audioPlayer.setVolume(bgmVolume);
    }
  }
}
