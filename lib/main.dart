import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/game/dungeon_game.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final game = DungeonGame();

  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: Colors.black,
        body: GameMain(game: game),
      ),
    ),
  );
}

class GameMain extends StatelessWidget {
  final DungeonGame game;
  const GameMain({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GameState>(
      valueListenable: game.gameState,
      builder: (context, state, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            GameWidget(
              game: game,
              overlayBuilderMap: {
                'PauseMenu': (context, DungeonGame game) => PauseMenu(game: game),
                'LevelComplete': (context, DungeonGame game) => LevelCompleteMenu(game: game),
                'GameOver': (context, DungeonGame game) => GameOverMenu(game: game),
              },
            ),
            if (state == GameState.playing) ...[
              ControlsOverlay(game: game),
              AudioControls(game: game),
            ],
            if (state == GameState.splash) SplashScreen(game: game),
            if (state == GameState.levelSelection) LevelSelectionScreen(game: game),
          ],
        );
      },
    );
  }
}

class LevelSelectionScreen extends StatefulWidget {
  final DungeonGame game;
  const LevelSelectionScreen({super.key, required this.game});

  @override
  State<LevelSelectionScreen> createState() => _LevelSelectionScreenState();
}

class _LevelSelectionScreenState extends State<LevelSelectionScreen> {
  int _page = 0; // 0 for 1-50, 1 for 51-100

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'SELECT LEVEL',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  Row(
                    children: [
                      _pageButton(0, '1-50'),
                      const SizedBox(width: 8),
                      _pageButton(1, '51-100'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<Set<int>>(
                valueListenable: widget.game.completedLevels,
                builder: (context, completed, _) {
                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1,
                    ),
                    itemCount: 50,
                    itemBuilder: (context, index) {
                      final levelNum = (_page * 50) + index + 1;
                      final isCompleted = completed.contains(levelNum);
                      final isUnlocked = levelNum == 1 || completed.contains(levelNum - 1);

                      return _levelBox(levelNum, isCompleted, isUnlocked);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageButton(int page, String label) {
    final isActive = _page == page;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? const Color(0xFF4285F4) : Colors.white10,
        foregroundColor: Colors.white,
      ),
      onPressed: () => setState(() => _page = page),
      child: Text(label),
    );
  }

  Widget _levelBox(int level, bool isCompleted, bool isUnlocked) {
    return GestureDetector(
      onTap: isUnlocked ? () => widget.game.loadLevel(level) : null,
      child: Container(
        decoration: BoxDecoration(
          color: isUnlocked ? (isCompleted ? Colors.green.withValues(alpha: 0.3) : Colors.white10) : Colors.black38,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUnlocked ? (isCompleted ? Colors.greenAccent : Colors.white24) : Colors.white10,
            width: 2,
          ),
          boxShadow: isUnlocked ? [
            BoxShadow(
              color: isCompleted ? Colors.green.withValues(alpha: 0.2) : Colors.black26,
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ] : null,
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                '$level',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isUnlocked ? Colors.white : Colors.white24,
                ),
              ),
            ),
            if (isCompleted)
              const Positioned(
                right: 4,
                top: 4,
                child: Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
              ),
            if (!isUnlocked)
              const Center(
                child: Icon(Icons.lock, color: Colors.white10, size: 32),
              ),
          ],
        ),
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  final DungeonGame game;
  const SplashScreen({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A1A), Color(0xFF2D2D2D)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'DUNGEON EXPLORER',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'A Google Brand Adventure',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white70,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 60),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4285F4),
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () {
                game.gameState.value = GameState.levelSelection;
              },
              child: const Text(
                'PLAY GAME',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PauseMenu extends StatelessWidget {
  final DungeonGame game;
  const PauseMenu({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'PAUSED',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 32),
              _menuButton(
                label: 'RESUME',
                color: const Color(0xFF4285F4),
                onPressed: () {
                  game.gameState.value = GameState.playing;
                  game.overlays.remove('PauseMenu');
                },
              ),
              const SizedBox(height: 12),
              _menuButton(
                label: 'EXIT TO MENU',
                color: Colors.redAccent.withValues(alpha: 0.8),
                onPressed: () {
                  game.overlays.remove('PauseMenu');
                  game.goToLevelSelection();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuButton({required String label, required Color color, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}

class LevelCompleteMenu extends StatelessWidget {
  final DungeonGame game;
  const LevelCompleteMenu({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.greenAccent.withValues(alpha: 0.1),
                blurRadius: 20,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stars, color: Colors.greenAccent, size: 50),
              const SizedBox(height: 13),
              Text(
                'FLOOR ${game.currentFloor} COMPLETE',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem('XP', '+${50 + game.currentFloor * 20}'),
                    _statItem('LVL', '${game.playerStats.level}'),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              _menuButton(
                label: 'NEXT LEVEL',
                color: const Color(0xFF4285F4),
                onPressed: () => game.startNextLevel(),
              ),
              const SizedBox(height: 4),
              _menuButton(
                label: 'BACK TO LIST',
                color: Colors.white10,
                onPressed: () => game.goToLevelSelection(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _menuButton({required String label, required Color color, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class GameOverMenu extends StatelessWidget {
  final DungeonGame game;
  const GameOverMenu({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.red.withValues(alpha: 0.2),
      child: Center(
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.ac_unit, color: Colors.redAccent, size: 64),
              const SizedBox(height: 16),
              const Text(
                'YOU DIED',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2),
              ),
              const SizedBox(height: 32),
              _menuButton(
                label: 'TRY AGAIN',
                color: Colors.redAccent.withValues(alpha: 0.8),
                onPressed: () {
                  game.playerStats.health = game.playerStats.maxHealth;
                  game.loadLevel(game.currentFloor);
                  game.overlays.remove('GameOver');
                },
              ),
              const SizedBox(height: 12),
              _menuButton(
                label: 'BACK TO LEVELS',
                color: Colors.white10,
                onPressed: () {
                  game.overlays.remove('GameOver');
                  game.goToLevelSelection();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuButton({required String label, required Color color, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class ControlsOverlay extends StatelessWidget {
  final DungeonGame game;

  const ControlsOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 12,
          bottom: 12,
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(0, 0, 0, 0.25),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12, width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _directionButton('↑', 0, -1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _directionButton('←', -1, 0),
                      const SizedBox(width: 12),
                      _directionButton('↓', 0, 1),
                      const SizedBox(width: 12),
                      _directionButton('→', 1, 0),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: SafeArea(
            child: IconButton(
              icon: const Icon(Icons.pause_circle_filled, size: 48, color: Colors.white70),
              onPressed: () {
                game.gameState.value = GameState.paused;
                game.overlays.add('PauseMenu');
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _directionButton(String label, int dx, int dy) {
    return GestureDetector(
      onTapDown: (_) => game.movePlayerBy(dx, dy),
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color.fromRGBO(255, 255, 255, 0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white30, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class AudioControls extends StatefulWidget {
  final DungeonGame game;
  const AudioControls({super.key, required this.game});

  @override
  State<AudioControls> createState() => _AudioControlsState();
}

class _AudioControlsState extends State<AudioControls> {
  bool _isMuted = false;
  double _volume = 0.6;

  @override
  void initState() {
    super.initState();
    _isMuted = widget.game.audioManager.isMuted;
    _volume = widget.game.audioManager.sfxVolume;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      top: 16,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(0, 0, 0, 0.4),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    widget.game.audioManager.toggleMute();
                    _isMuted = widget.game.audioManager.isMuted;
                  });
                },
              ),
              if (!_isMuted)
                SizedBox(
                  width: 100,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    ),
                    child: Slider(
                      value: _volume,
                      min: 0.0,
                      max: 1.0,
                      activeColor: Colors.white70,
                      inactiveColor: Colors.white24,
                      onChanged: (value) {
                        setState(() {
                          _volume = value;
                          widget.game.audioManager.setVolume(value);
                        });
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

