import 'dart:math';

import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../components/player/player_stats.dart';
import '../../core/audio/audio_manager.dart';
import '../../core/save/save_manager.dart';
import '../../data/models/dungeon_data.dart';
import '../../procedural/dungeon_generator/dungeon_generator.dart';
import '../../systems/achievement/achievement_manager.dart';
import '../../systems/combat/combat_system.dart';
import '../../systems/equipment/equipment_manager.dart';
import '../../systems/inventory/inventory_system.dart';
import '../../systems/loot/loot_system.dart';
import '../../systems/minimap/minimap_manager.dart';
import '../../systems/quests/quest_manager.dart';
import '../../systems/skills/skill_system.dart';

import '../../data/models/enemy.dart';
import '../../systems/enemy/enemy_ai.dart';

class DungeonGame extends FlameGame with KeyboardEvents {
  late DungeonData dungeon;
  late PlayerStats playerStats;
  late InventorySystem inventorySystem;
  late EquipmentManager equipmentManager;
  late CombatSystem combatSystem;
  late SkillSystem skillSystem;
  late QuestManager questManager;
  late AchievementManager achievementManager;
  late MinimapManager minimapManager;
  late AudioManager audioManager;
  late SaveManager saveManager;
  late EnemyAI enemyAI;

  int currentFloor = 1;
  Offset playerPosition = Offset.zero;
  final List<Enemy> enemies = [];
  double combatCooldown = 0.0;
  double elapsedTime = 0.0;
  double floorBannerTimer = 2.5;
  static const int maxFloor = 10;
  static const double tileSize = 18.0;
  final TextPaint debugText = TextPaint(
    style: const TextStyle(color: Colors.white, fontSize: 12),
  );

  double get _worldWidth => dungeon.width * tileSize;
  double get _worldHeight => dungeon.height * tileSize;
  bool get _isFinalFloor => currentFloor >= maxFloor;

  @override
  Color backgroundColor() => const Color(0xFF1A1A1A);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    dungeon = DungeonGenerator(
      width: 40,
      height: 24,
      maxLeafSize: 12,
      floor: currentFloor,
    ).generate();
    playerPosition = dungeon.rooms.isNotEmpty
        ? dungeon.rooms.first.center
        : const Offset(2, 2);

    playerStats = PlayerStats();
    inventorySystem = InventorySystem();
    equipmentManager = EquipmentManager();
    combatSystem = CombatSystem();
    skillSystem = SkillSystem();
    questManager = QuestManager();
    achievementManager = AchievementManager();
    minimapManager = MinimapManager(dungeon.width, dungeon.height)
      ..revealRoomArea(dungeon);
    audioManager = AudioManager();
    saveManager = SaveManager();
    enemyAI = EnemyAI();

    final startingLoot = LootSystem().generateLoot();
    inventorySystem.addItem(startingLoot);

    _spawnEnemies();
  }

  void _spawnEnemies() {
    enemies.clear();
    if (dungeon.rooms.length <= 1) return;

    final random = Random();
    final enemyCount = _isFinalFloor
        ? min(1, dungeon.rooms.length - 1)
        : min(2 + currentFloor, dungeon.rooms.length - 1);

    for (int i = 0; i < enemyCount && i < dungeon.rooms.length - 1; i++) {
      final room = dungeon.rooms[i + 1];
      final centerX = room.x + 1 + random.nextInt(max(1, room.width - 2));
      final centerY = room.y + 1 + random.nextInt(max(1, room.height - 2));
      final enemyType = _enemyTypeForFloor(i);

      final enemy = Enemy(
        id: 'enemy_${currentFloor}_$i',
        type: enemyType,
        health: _enemyHealth(enemyType),
        damage: _enemyDamage(enemyType),
        defense: _enemyDefense(enemyType),
        x: centerX.toDouble(),
        y: centerY.toDouble(),
      );
      enemies.add(enemy);
    }
  }

  EnemyType _enemyTypeForFloor(int index) {
    if (_isFinalFloor) return EnemyType.boss;
    if (currentFloor >= 8 && index.isEven) return EnemyType.knight;
    if (currentFloor >= 6 && index % 3 == 0) return EnemyType.mage;
    if (currentFloor >= 4 && index.isEven) return EnemyType.spider;
    if (currentFloor >= 3) return EnemyType.skeleton;
    return index.isEven ? EnemyType.goblin : EnemyType.slime;
  }

  int _enemyHealth(EnemyType type) {
    final floorBonus = currentFloor * 6;
    return switch (type) {
      EnemyType.slime => 14 + floorBonus,
      EnemyType.goblin => 18 + floorBonus,
      EnemyType.skeleton => 24 + floorBonus,
      EnemyType.spider => 28 + floorBonus,
      EnemyType.mage => 36 + floorBonus,
      EnemyType.knight => 48 + floorBonus,
      EnemyType.boss => 180 + (currentFloor * 20),
    };
  }

  int _enemyDamage(EnemyType type) {
    final floorBonus = currentFloor * 2;
    return switch (type) {
      EnemyType.slime => 3 + floorBonus,
      EnemyType.goblin => 4 + floorBonus,
      EnemyType.skeleton => 5 + floorBonus,
      EnemyType.spider => 6 + floorBonus,
      EnemyType.mage => 8 + floorBonus,
      EnemyType.knight => 10 + floorBonus,
      EnemyType.boss => 18 + floorBonus,
    };
  }

  int _enemyDefense(EnemyType type) {
    return switch (type) {
      EnemyType.slime => 1 + currentFloor ~/ 3,
      EnemyType.goblin => 1 + currentFloor ~/ 2,
      EnemyType.skeleton => 2 + currentFloor ~/ 2,
      EnemyType.spider => 2 + currentFloor ~/ 2,
      EnemyType.mage => 3 + currentFloor ~/ 2,
      EnemyType.knight => 5 + currentFloor,
      EnemyType.boss => 12 + currentFloor,
    };
  }

  @override
  void update(double dt) {
    super.update(dt);
    elapsedTime += dt;
    if (floorBannerTimer > 0) {
      floorBannerTimer -= dt;
    }

    final currentTileX = playerPosition.dx.toInt();
    final currentTileY = playerPosition.dy.toInt();
    minimapManager.revealTile(currentTileX, currentTileY);

    combatCooldown -= dt;
    if (combatCooldown <= 0) {
      _checkEnemyCollisions();
    }

    // Remove dead enemies
    enemies.removeWhere((enemy) => enemy.health <= 0);
  }

  void _checkEnemyCollisions() {
    for (final enemy in enemies) {
      const detectionRange = 2;
      final dx = (enemy.x - playerPosition.dx).abs();
      final dy = (enemy.y - playerPosition.dy).abs();

      if (dx <= detectionRange && dy <= detectionRange) {
        final damage = combatSystem.calculateEnemyDamage(enemy, playerStats);
        playerStats.takeDamage(damage);
        combatCooldown = 1.0;

        if (playerStats.health <= 0) {
          _playerDied();
        }
        break;
      }
    }
  }

  void _playerDied() {
    playerStats.health = playerStats.maxHealth;
    playerStats.level = 1;
    playerStats.experience = 0;
    currentFloor = 1;
    _regenerateDungeon();
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (event is KeyDownEvent) {
      if (keysPressed.contains(LogicalKeyboardKey.arrowUp) ||
          keysPressed.contains(LogicalKeyboardKey.keyW)) {
        movePlayerBy(0, -1);
        return KeyEventResult.handled;
      }
      if (keysPressed.contains(LogicalKeyboardKey.arrowDown) ||
          keysPressed.contains(LogicalKeyboardKey.keyS)) {
        movePlayerBy(0, 1);
        return KeyEventResult.handled;
      }
      if (keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
          keysPressed.contains(LogicalKeyboardKey.keyA)) {
        movePlayerBy(-1, 0);
        return KeyEventResult.handled;
      }
      if (keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
          keysPressed.contains(LogicalKeyboardKey.keyD)) {
        movePlayerBy(1, 0);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void movePlayerBy(int dx, int dy) {
    final targetX = playerPosition.dx.toInt() + dx;
    final targetY = playerPosition.dy.toInt() + dy;
    if (_canMoveTo(targetX, targetY)) {
      playerPosition = Offset(targetX.toDouble(), targetY.toDouble());
      _checkFloorTransition();
    }
  }

  void _checkFloorTransition() {
    final currentTile = dungeon.getTile(
      playerPosition.dx.toInt(),
      playerPosition.dy.toInt(),
    );
    if (currentTile == TileType.stairDown && !_isFinalFloor) {
      _nextFloor();
    } else if (currentTile == TileType.stairUp && currentFloor > 1) {
      _previousFloor();
    }
  }

  void _nextFloor() {
    if (_isFinalFloor) return;
    currentFloor += 1;
    playerStats.gainExperience(50 + currentFloor * 20);
    playerStats.heal(15 + currentFloor * 2);
    playerStats.restoreMana(10 + currentFloor * 2);
    _regenerateDungeon();
  }

  void _previousFloor() {
    currentFloor -= 1;
    _regenerateDungeon();
  }

  void _regenerateDungeon() {
    dungeon = DungeonGenerator(
      width: 40,
      height: 24,
      maxLeafSize: 12,
      floor: currentFloor,
    ).generate();
    playerPosition = dungeon.rooms.isNotEmpty
        ? dungeon.rooms.first.center
        : const Offset(2, 2);
    minimapManager = MinimapManager(dungeon.width, dungeon.height)
      ..revealRoomArea(dungeon);
    _spawnEnemies();
    floorBannerTimer = 2.5;
  }

  bool _canMoveTo(int x, int y) {
    final tile = dungeon.getTile(x, y);
    return tile == TileType.floor ||
        tile == TileType.door ||
        tile == TileType.stairUp ||
        tile == TileType.stairDown;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final scale = min(size.x / _worldWidth, size.y / _worldHeight);
    final offsetX = (size.x - (_worldWidth * scale)) / 2;
    final offsetY = (size.y - (_worldHeight * scale)) / 2;

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale);
    _drawDungeon(canvas);
    _drawEnemies(canvas);
    _drawPlayer(canvas);
    canvas.restore();

    _drawHud(canvas);
  }

  void _drawDungeon(Canvas canvas) {
    for (int y = 0; y < dungeon.height; y++) {
      for (int x = 0; x < dungeon.width; x++) {
        final tile = dungeon.getTile(x, y);
        final rect = Rect.fromLTWH(
          x * tileSize,
          y * tileSize,
          tileSize,
          tileSize,
        );
        final paint = Paint();
        switch (tile) {
          case TileType.wall:
            paint.color = const Color(0xFF151515);
            break;
          case TileType.floor:
            paint.color = const Color(0xFF444444);
            break;
          case TileType.door:
            paint.color = const Color(0xFF8B6F47);
            break;
          case TileType.stairUp:
            paint.color = const Color(0xFF3C9C82);
            break;
          case TileType.stairDown:
            paint.color = const Color(0xFF6C54B7);
            break;
        }
        canvas.drawRect(rect, paint);
      }
    }
  }

  void _drawPlayer(Canvas canvas) {
    final paint = Paint()..color = const Color(0xFFECE859);
    final position = Offset(
      playerPosition.dx * tileSize + tileSize / 2,
      playerPosition.dy * tileSize + tileSize / 2,
    );
    canvas.drawCircle(position, tileSize * 0.4, paint);
  }

  void _drawEnemies(Canvas canvas) {
    final paint = Paint()..color = const Color(0xFFFF6B6B);
    for (final enemy in enemies) {
      final position = Offset(
        enemy.x * tileSize + tileSize / 2,
        enemy.y * tileSize + tileSize / 2,
      );
      canvas.drawCircle(position, tileSize * 0.35, paint);
    }
  }

  void _drawHud(Canvas canvas) {
    final hudMargin = 14.0;
    final hudPadding = 10.0;
    final lineHeight = 15.0;
    final panelWidth = 240.0;
    final panelHeight = 130.0;

    // Draw HUD background panel
    final hudBg = Paint()
      ..color = const Color.fromARGB(210, 15, 15, 25)
      ..style = PaintingStyle.fill;
    final hudBorder = Paint()
      ..color = const Color.fromARGB(180, 100, 200, 255)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final hudRect = Rect.fromLTWH(
      hudMargin,
      hudMargin,
      panelWidth,
      panelHeight,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(hudRect, const Radius.circular(10)),
      hudBg,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(hudRect, const Radius.circular(10)),
      hudBorder,
    );

    // Draw HUD text
    final textX = hudMargin + hudPadding;
    var textY = hudMargin + hudPadding;

    debugText.render(canvas, 'Floor: $currentFloor', Vector2(textX, textY));
    textY += lineHeight;

    debugText.render(
      canvas,
      'HP: ${playerStats.health}/${playerStats.maxHealth}',
      Vector2(textX, textY),
    );
    textY += lineHeight;

    debugText.render(
      canvas,
      'Mana: ${playerStats.mana}/${playerStats.maxMana}',
      Vector2(textX, textY),
    );
    textY += lineHeight;

    debugText.render(
      canvas,
      'Lvl: ${playerStats.level} XP: ${playerStats.experience}',
      Vector2(textX, textY),
    );
    textY += lineHeight;

    debugText.render(
      canvas,
      'Inv: ${inventorySystem.items.length}/${inventorySystem.capacity}',
      Vector2(textX, textY),
    );
    textY += lineHeight;

    debugText.render(
      canvas,
      'Enemies: ${enemies.length}',
      Vector2(textX, textY),
    );
  }
}
