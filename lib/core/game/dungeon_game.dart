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
  Offset keyPosition = Offset.zero;
  final List<Enemy> enemies = [];
  double combatCooldown = 0.0;
  double enemyMoveTimer = 0.0;
  double elapsedTime = 0.0;
  double floorBannerTimer = 2.5;
  bool hasKey = false;
  bool gameWon = false;
  static const int maxFloor = 10;
  static const double tileSize = 18.0;
  final TextPaint debugText = TextPaint(
    style: const TextStyle(
      color: Color(0xFF1F2937),
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
  );
  final TextPaint bannerText = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 30,
      fontWeight: FontWeight.bold,
    ),
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
    _removeBackStairs();
    _placeKey();
    audioManager.playSound('floor');
  }

  void _removeBackStairs() {
    for (int y = 0; y < dungeon.height; y++) {
      for (int x = 0; x < dungeon.width; x++) {
        if (dungeon.getTile(x, y) == TileType.stairUp) {
          dungeon.setTile(x, y, TileType.floor);
        }
      }
    }
  }

  void _placeKey() {
    hasKey = false;
    if (dungeon.rooms.length < 2) {
      keyPosition = playerPosition;
      return;
    }

    final keyRoom = dungeon.rooms[max(1, dungeon.rooms.length ~/ 2)];
    keyPosition = keyRoom.center;
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
    if (gameWon) return;

    final currentTileX = playerPosition.dx.toInt();
    final currentTileY = playerPosition.dy.toInt();
    minimapManager.revealTile(currentTileX, currentTileY);

    enemyMoveTimer -= dt;
    if (enemyMoveTimer <= 0) {
      _moveEnemies();
      enemyMoveTimer = max(0.28, 0.95 - currentFloor * 0.06);
    }

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
        } else {
          audioManager.playSound('hit');
        }
        break;
      }
    }
  }

  void _playerDied() {
    audioManager.playSound('death');
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
    if (gameWon) return;
    final targetX = playerPosition.dx.toInt() + dx;
    final targetY = playerPosition.dy.toInt() + dy;
    final enemy = _enemyAt(targetX, targetY);
    if (enemy != null) {
      _attackEnemy(enemy);
      return;
    }

    if (_canMoveTo(targetX, targetY)) {
      playerPosition = Offset(targetX.toDouble(), targetY.toDouble());
      audioManager.playSound('move');
      _checkKeyPickup();
      _checkFloorTransition();
    } else {
      audioManager.playSound('blocked');
    }
  }

  Enemy? _enemyAt(int x, int y, {Enemy? except}) {
    for (final enemy in enemies) {
      if (enemy == except) continue;
      if (enemy.x.toInt() == x && enemy.y.toInt() == y) {
        return enemy;
      }
    }
    return null;
  }

  void _attackEnemy(Enemy enemy) {
    final damage = max(1, playerStats.strength + playerStats.level - enemy.defense);
    enemy.health -= damage;
    audioManager.playSound(enemy.type == EnemyType.boss ? 'boss' : 'attack');
    combatCooldown = 0.45;

    if (enemy.health <= 0) {
      playerStats.gainExperience(
        enemy.type == EnemyType.boss ? 500 : 25 + currentFloor * 8,
      );
      if (enemy.type == EnemyType.boss) {
        enemies.remove(enemy);
        gameWon = true;
        floorBannerTimer = 4.0;
        audioManager.playSound('floor');
      }
    }
  }

  void _checkKeyPickup() {
    if (hasKey) return;
    if (playerPosition.dx.toInt() == keyPosition.dx.toInt() &&
        playerPosition.dy.toInt() == keyPosition.dy.toInt()) {
      hasKey = true;
      floorBannerTimer = 2.5;
      audioManager.playSound('key');
    }
  }

  void _checkFloorTransition() {
    final currentTile = dungeon.getTile(
      playerPosition.dx.toInt(),
      playerPosition.dy.toInt(),
    );
    if (currentTile == TileType.stairDown && !_isFinalFloor && hasKey) {
      _nextFloor();
    } else if (currentTile == TileType.stairDown && !hasKey) {
      audioManager.playSound('blocked');
      floorBannerTimer = 1.6;
    }
  }

  void _moveEnemies() {
    final random = Random();
    for (final enemy in enemies) {
      final distanceX = playerPosition.dx - enemy.x;
      final distanceY = playerPosition.dy - enemy.y;
      final playerDistance = max(distanceX.abs(), distanceY.abs());
      var stepX = 0;
      var stepY = 0;

      if (playerDistance <= _enemyChaseRange(enemy.type)) {
        if (distanceX.abs() > distanceY.abs()) {
          stepX = distanceX.sign.toInt();
        } else {
          stepY = distanceY.sign.toInt();
        }
      } else if (random.nextDouble() < 0.55) {
        final direction = random.nextInt(4);
        stepX = direction == 0
            ? 1
            : direction == 1
            ? -1
            : 0;
        stepY = direction == 2
            ? 1
            : direction == 3
            ? -1
            : 0;
      }

      final targetX = enemy.x.toInt() + stepX;
      final targetY = enemy.y.toInt() + stepY;
      if (stepX == 0 && stepY == 0) continue;
      if (!_canMoveTo(targetX, targetY)) continue;
      if (targetX == playerPosition.dx.toInt() &&
          targetY == playerPosition.dy.toInt()) {
        continue;
      }
      if (_enemyAt(targetX, targetY, except: enemy) != null) continue;

      enemy.x = targetX.toDouble();
      enemy.y = targetY.toDouble();
      if (enemy.type == EnemyType.boss) {
        audioManager.playSound('enemyMove');
      }
    }
  }

  int _enemyChaseRange(EnemyType type) {
    return switch (type) {
      EnemyType.slime => 3,
      EnemyType.goblin => 4,
      EnemyType.skeleton => 5,
      EnemyType.spider => 6,
      EnemyType.mage => 7,
      EnemyType.knight => 7,
      EnemyType.boss => 10,
    };
  }

  void _nextFloor() {
    if (_isFinalFloor) return;
    currentFloor += 1;
    playerStats.gainExperience(50 + currentFloor * 20);
    playerStats.heal(15 + currentFloor * 2);
    playerStats.restoreMana(10 + currentFloor * 2);
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
    _removeBackStairs();
    _spawnEnemies();
    _placeKey();
    floorBannerTimer = 2.5;
    audioManager.playSound(_isFinalFloor ? 'boss' : 'floor');
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
    _drawKey(canvas);
    _drawEnemies(canvas);
    _drawPlayer(canvas);
    canvas.restore();

    _drawHud(canvas);
    _drawFloorBanner(canvas);
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
            paint.color = (x + y) % 2 == 0
                ? const Color(0xFF4A5261)
                : const Color(0xFF3F4654);
            break;
          case TileType.floor:
            paint.color = (x + y) % 2 == 0
                ? const Color(0xFF69717F)
                : const Color(0xFF5B6370);
            break;
          case TileType.door:
            paint.color = const Color(0xFFB4864F);
            break;
          case TileType.stairUp:
            paint.color = const Color(0xFF55C79E);
            break;
          case TileType.stairDown:
            paint.color = hasKey || _isFinalFloor
                ? const Color(0xFF8F7BFF)
                : const Color(0xFF5E6170);
            break;
        }
        canvas.drawRect(rect, paint);
        if (tile == TileType.floor) {
          canvas.drawRect(
            rect.deflate(1),
            Paint()
              ..color = const Color.fromARGB(40, 255, 255, 255)
              ..style = PaintingStyle.stroke,
          );
        } else if (tile == TileType.wall) {
          canvas.drawRect(
            rect.deflate(2),
            Paint()
              ..color = const Color.fromARGB(30, 255, 255, 255)
              ..style = PaintingStyle.stroke,
          );
        } else if (tile == TileType.stairDown && !hasKey && !_isFinalFloor) {
          canvas.drawLine(
            rect.topLeft.translate(3, 3),
            rect.bottomRight.translate(-3, -3),
            Paint()
              ..color = const Color.fromARGB(180, 255, 180, 120)
              ..strokeWidth = 2,
          );
          canvas.drawCircle(
            rect.center,
            tileSize * 0.22,
            Paint()
              ..color = const Color.fromARGB(210, 255, 220, 140)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }
      }
    }
  }

  void _drawPlayer(Canvas canvas) {
    final pulse = 1 + sin(elapsedTime * 6) * 0.08;
    final glowPaint = Paint()
      ..color = const Color.fromARGB(80, 236, 232, 89)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final paint = Paint()..color = const Color(0xFFECE859);
    final position = Offset(
      playerPosition.dx * tileSize + tileSize / 2,
      playerPosition.dy * tileSize + tileSize / 2,
    );
    canvas.drawCircle(position, tileSize * 0.65 * pulse, glowPaint);
    canvas.drawCircle(position, tileSize * 0.4 * pulse, paint);
  }

  void _drawKey(Canvas canvas) {
    if (_isFinalFloor || hasKey) return;

    final position = Offset(
      keyPosition.dx * tileSize + tileSize / 2,
      keyPosition.dy * tileSize + tileSize / 2,
    );

    canvas.drawCircle(
      position,
      tileSize * (0.55 + sin(elapsedTime * 5) * 0.08),
      Paint()
        ..color = const Color.fromARGB(120, 255, 213, 79)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawCircle(
      position.translate(-tileSize * 0.18, 0),
      tileSize * 0.22,
      Paint()
        ..color = const Color(0xFFFFD54F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawLine(
      position.translate(tileSize * 0.02, 0),
      position.translate(tileSize * 0.42, 0),
      Paint()
        ..color = const Color(0xFFFFD54F)
        ..strokeWidth = 3,
    );
    canvas.drawLine(
      position.translate(tileSize * 0.28, 0),
      position.translate(tileSize * 0.28, tileSize * 0.18),
      Paint()
        ..color = const Color(0xFFFFD54F)
        ..strokeWidth = 3,
    );
  }

  void _drawEnemies(Canvas canvas) {
    for (final enemy in enemies) {
      final pulse = 1 + sin(elapsedTime * 4 + enemy.x + enemy.y) * 0.06;
      final paint = Paint()..color = _enemyColor(enemy.type);
      final position = Offset(
        enemy.x * tileSize + tileSize / 2,
        enemy.y * tileSize + tileSize / 2,
      );
      canvas.drawCircle(position, tileSize * _enemyRadius(enemy.type) * pulse, paint);
      canvas.drawCircle(
        position,
        tileSize * _enemyRadius(enemy.type) * pulse,
        Paint()
          ..color = Colors.black54
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  Color _enemyColor(EnemyType type) {
    return switch (type) {
      EnemyType.slime => const Color(0xFF79D36B),
      EnemyType.goblin => const Color(0xFFFF9C54),
      EnemyType.skeleton => const Color(0xFFD8D8C8),
      EnemyType.spider => const Color(0xFFB86AD8),
      EnemyType.mage => const Color(0xFF64B5F6),
      EnemyType.knight => const Color(0xFFE57373),
      EnemyType.boss => const Color(0xFFFFD54F),
    };
  }

  double _enemyRadius(EnemyType type) {
    return type == EnemyType.boss ? 0.62 : 0.35;
  }

  void _drawHud(Canvas canvas) {
    final hudMargin = 14.0;
    final hudPadding = 10.0;
    final lineHeight = 15.0;
    final panelWidth = min(130.0, size.x - hudMargin * 2);
    final panelHeight = 204.0;
    final hudX = max(hudMargin, size.x - panelWidth - hudMargin);

    // Draw HUD background panel
    final hudBg = Paint()
      ..color = const Color.fromARGB(110, 236, 236, 236)
      ..style = PaintingStyle.fill;
    final hudBorder = Paint()
      ..color = const Color(0xFF7DD3FC)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final hudShadow = Paint()
      ..color = const Color.fromARGB(75, 15, 23, 42)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final hudRect = Rect.fromLTWH(
      hudX,
      hudMargin,
      panelWidth,
      panelHeight,
    );

    final hudShape = RRect.fromRectAndRadius(
      hudRect,
      const Radius.circular(10),
    );

    canvas.drawRRect(hudShape.shift(const Offset(0, 3)), hudShadow);
    canvas.drawRRect(hudShape, hudBg);
    canvas.drawRRect(hudShape, hudBorder);

    // Draw HUD text
    final textX = hudX + hudPadding;
    var textY = hudMargin + hudPadding;

    debugText.render(
      canvas,
      'DETAILS',
      Vector2(textX, textY),
    );
    textY += lineHeight + 2;

    debugText.render(canvas, 'Floor: $currentFloor / $maxFloor', Vector2(textX, textY));
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
    textY += lineHeight;

    debugText.render(
      canvas,
      _isFinalFloor ? 'Final floor' : 'Next: Floor ${currentFloor + 1}',
      Vector2(textX, textY),
    );
    textY += lineHeight;

    debugText.render(
      canvas,
      'Key: ${hasKey ? 'FOUND' : 'MISSING'}',
      Vector2(textX, textY),
    );
    textY += lineHeight;

    debugText.render(
      canvas,
      'Power: STR ${playerStats.strength} DEF ${playerStats.defense}',
      Vector2(textX, textY),
    );
    textY += lineHeight;

    final objective = _isFinalFloor
        ? gameWon
              ? 'Boss defeated'
              : 'Objective: defeat boss'
        : hasKey
        ? 'Objective: enter portal'
        : 'Objective: find key';
    debugText.render(canvas, objective, Vector2(textX, textY));
  }

  void _drawFloorBanner(Canvas canvas) {
    if (floorBannerTimer <= 0) return;

    final alpha = (floorBannerTimer / 2.5).clamp(0.0, 1.0);
    final bannerWidth = min(size.x - 32, 420.0);
    final bannerRect = Rect.fromCenter(
      center: Offset(size.x / 2, 52),
      width: bannerWidth,
      height: 58,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(bannerRect, const Radius.circular(14)),
      Paint()..color = Color.fromRGBO(20, 24, 34, 0.60 * alpha),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bannerRect, const Radius.circular(14)),
      Paint()
        ..color = Color.fromRGBO(255, 255, 255, 0.22 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final title = gameWon
        ? 'Dungeon Cleared!'
        : _isFinalFloor
        ? 'Floor 10: Boss Chamber'
        : hasKey
        ? 'Portal unlocked'
        : 'Find the key';
    bannerText.render(
      canvas,
      title,
      Vector2(size.x / 2 - title.length * 8.5, 34),
    );
  }
}
