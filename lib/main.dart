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
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            GameWidget(game: game),
            ControlsOverlay(game: game),
          ],
        ),
      ),
    ),
  );
}

class ControlsOverlay extends StatelessWidget {
  final DungeonGame game;

  const ControlsOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      bottom: 20,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(0, 0, 0, 0.55),
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
    );
  }

  Widget _directionButton(String label, int dx, int dy) {
    return GestureDetector(
      onTap: () => game.movePlayerBy(dx, dy),
      child: Container(
        width: 70,
        height: 70,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color.fromRGBO(255, 255, 255, 0.14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
