import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter/services.dart';

import '../../components/player/player_stats.dart';
import '../../core/audio/audio_manager.dart';
import '../../core/save/save_manager.dart';
import '../../data/models/dungeon_data.dart';
import '../../data/models/quest.dart';
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
import 'package:url_launcher/url_launcher.dart';

enum GameState { splash, levelSelection, playing, paused, levelComplete, gameOver }

class DungeonGame extends FlameGame with KeyboardEvents, TapCallbacks {
  late DungeonData dungeon;
  final PlayerStats playerStats = PlayerStats();
  final InventorySystem inventorySystem = InventorySystem();
  final EquipmentManager equipmentManager = EquipmentManager();
  final CombatSystem combatSystem = CombatSystem();
  final SkillSystem skillSystem = SkillSystem();
  final QuestManager questManager = QuestManager();
  final AchievementManager achievementManager = AchievementManager();
  late MinimapManager minimapManager;
  final AudioManager audioManager = AudioManager();
  late SaveManager saveManager;
  late EnemyAI enemyAI;

  final ValueNotifier<GameState> gameState = ValueNotifier(GameState.splash);
  final ValueNotifier<Set<int>> completedLevels = ValueNotifier({});
  static const int totalLevels = 100;
  
  late Sprite playerSprite;
  final Map<EnemyType, Sprite> enemySprites = {};

  final List<AnimatedDot> trailDots = [];
  Quest? activeQuest;
  int _lootChestsOpened = 0;
  final List<Offset> chests = [];
  final Set<int> _exploredRoomIndices = {};

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
  static const int maxFloor = 100;
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
      fontSize: 24,
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
    
    // Load Sprites
    playerSprite = await loadSprite('player.png');
    for (var type in EnemyType.values) {
      final fileName = type == EnemyType.boss ? 'boss.png' : '${type.name}.png';
      enemySprites[type] = await loadSprite('enemies/$fileName');
    }

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
    await audioManager.initialize();

    saveManager = SaveManager();
    enemyAI = EnemyAI();

    final startingLoot = LootSystem().generateLoot();
    inventorySystem.addItem(startingLoot);

    _spawnEnemies();
    _removeBackStairs();
    _placeKey();
    _spawnChests();
    _generateFloorQuest();
    audioManager.playSound('floor');
    audioManager.playMusic('main');
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

  void _spawnChests() {
    chests.clear();
    if (dungeon.rooms.length <= 1) return;

    final random = Random();
    final chestCount = 1 + random.nextInt(3);
    for (int i = 0; i < chestCount; i++) {
      final room = dungeon.rooms[1 + random.nextInt(dungeon.rooms.length - 1)];
      final chestX = room.x + 1 + random.nextInt(max(1, room.width - 2));
      final chestY = room.y + 1 + random.nextInt(max(1, room.height - 2));

      final chestPos = Offset(chestX.toDouble(), chestY.toDouble());
      if (!chests.contains(chestPos) && chestPos != keyPosition && chestPos != playerPosition) {
        chests.add(chestPos);
      }
    }
  }

  void _generateFloorQuest() {
    if (_isFinalFloor) {
      activeQuest = Quest(
        id: 'floor_quest_$currentFloor',
        title: 'Slay the Boss',
        type: QuestType.defeatBoss,
        description: 'Defeat the dungeon guardian to escape!',
        target: 1,
      );
    } else {
      final random = Random();
      final questTypeVal = random.nextInt(3);
      if (questTypeVal == 0) {
        final killTarget = 2 + (currentFloor ~/ 2) + random.nextInt(2);
        activeQuest = Quest(
          id: 'floor_quest_$currentFloor',
          title: 'Exterminate Monsters',
          type: QuestType.killEnemies,
          description: 'Slay $killTarget enemies on this floor.',
          target: killTarget,
        );
      } else if (questTypeVal == 1) {
        final maxRooms = dungeon.rooms.length;
        final exploreTarget = min(3 + currentFloor ~/ 2, max(2, maxRooms - 1));
        activeQuest = Quest(
          id: 'floor_quest_$currentFloor',
          title: 'Map the Area',
          type: QuestType.exploreRooms,
          description: 'Explore $exploreTarget rooms to find secret clues.',
          target: exploreTarget,
        );
        _exploredRoomIndices.clear();
        _exploredRoomIndices.add(0);
        activeQuest!.progress = 1;
      } else if (questTypeVal == 2) {
        final chestTarget = 1 + currentFloor ~/ 3;
        activeQuest = Quest(
          id: 'floor_quest_$currentFloor',
          title: 'Harvest Treasure',
          type: QuestType.collectItems,
          description: 'Open $chestTarget loot chests on this floor.',
          target: chestTarget,
        );
        _lootChestsOpened = 0;
      } else {
        activeQuest = Quest(
          id: 'floor_quest_$currentFloor',
          title: 'Riddle of the Floor',
          type: QuestType.solvePuzzle,
          description: 'Solve the ancient rune at the portal to proceed.',
          target: 1,
        );
      }
    }
    questManager.activeQuests.clear();
    questManager.addQuest(activeQuest!);
  }

  /// Called after every player action turn.
  void _onPlayerTurnEnd() {
    // Player turn logic can be expanded here
  }

  void _spawnEnemies() {
    enemies.clear();
    if (dungeon.rooms.length <= 1) return;

    final random = Random();
    final enemyCount = _isFinalFloor
        ? min(2, dungeon.rooms.length - 1)
        : min(3 + currentFloor * 2, dungeon.rooms.length - 1);

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
    final floorBonus = currentFloor * 9;
    return switch (type) {
      EnemyType.slime => 18 + floorBonus,
      EnemyType.goblin => 22 + floorBonus,
      EnemyType.skeleton => 30 + floorBonus,
      EnemyType.spider => 36 + floorBonus,
      EnemyType.mage => 45 + floorBonus,
      EnemyType.knight => 60 + floorBonus,
      EnemyType.boss => 250 + (currentFloor * 30),
    };
  }

  int _enemyDamage(EnemyType type) {
    final floorBonus = currentFloor * 3;
    return switch (type) {
      EnemyType.slime => 4 + floorBonus,
      EnemyType.goblin => 6 + floorBonus,
      EnemyType.skeleton => 8 + floorBonus,
      EnemyType.spider => 10 + floorBonus,
      EnemyType.mage => 12 + floorBonus,
      EnemyType.knight => 15 + floorBonus,
      EnemyType.boss => 24 + floorBonus,
    };
  }

  int _enemyDefense(EnemyType type) {
    return switch (type) {
      EnemyType.slime => 1 + currentFloor ~/ 2,
      EnemyType.goblin => 2 + currentFloor ~/ 2,
      EnemyType.skeleton => 3 + currentFloor ~/ 2,
      EnemyType.spider => 3 + currentFloor ~/ 2,
      EnemyType.mage => 4 + currentFloor ~/ 2,
      EnemyType.knight => 6 + currentFloor,
      EnemyType.boss => 15 + currentFloor,
    };
  }

  @override
  void update(double dt) {
    if (gameState.value != GameState.playing) return;

    super.update(dt);
    elapsedTime += dt;

    // Update particles
    for (final dot in trailDots) {
      dot.update(dt);
    }
    trailDots.removeWhere((dot) => dot.life <= 0);

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
      enemyMoveTimer = max(0.20, 0.90 - currentFloor * 0.08);
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

        _spawnDamageParticles(playerPosition);

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
    gameState.value = GameState.gameOver;
    overlays.add('GameOver');
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

  int _getRoomIndexAt(int x, int y) {
    for (int i = 0; i < dungeon.rooms.length; i++) {
      final room = dungeon.rooms[i];
      if (x >= room.x && x < room.x + room.width &&
          y >= room.y && y < room.y + room.height) {
        return i;
      }
    }
    return -1;
  }

  void movePlayerBy(int dx, int dy) {
    if (gameWon) return;

    final rawTargetX = playerPosition.dx.toInt() + dx;
    final rawTargetY = playerPosition.dy.toInt() + dy;
    final enemy = _enemyAt(rawTargetX, rawTargetY);
    if (enemy != null) {
      _attackEnemy(enemy);
      _onPlayerTurnEnd();
      return;
    }

    if (_canMoveTo(rawTargetX, rawTargetY)) {
      final oldPos = playerPosition;

      // Step into the target tile first
      playerPosition = Offset(rawTargetX.toDouble(), rawTargetY.toDouble());

      audioManager.playSound('move');
      _spawnMoveParticles(oldPos);
      _checkKeyPickup();
      _checkChestPickup();
      _checkFloorTransition();

      final finalX = playerPosition.dx.toInt();
      final finalY = playerPosition.dy.toInt();
      final roomIdx = _getRoomIndexAt(finalX, finalY);
      if (roomIdx != -1 && !_exploredRoomIndices.contains(roomIdx)) {
        _exploredRoomIndices.add(roomIdx);
        if (activeQuest?.type == QuestType.exploreRooms) {
          activeQuest!.progress = min(activeQuest!.target, _exploredRoomIndices.length);
          if (activeQuest!.progress >= activeQuest!.target && !activeQuest!.complete) {
            activeQuest!.complete = true;
            _spawnQuestCompleteParticles();
          }
        }
      }

      _onPlayerTurnEnd();
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
    _spawnDamageParticles(Offset(enemy.x, enemy.y));
    _spawnAttackParticles(playerPosition, Offset(enemy.x, enemy.y));

    audioManager.playSound(enemy.type == EnemyType.boss ? 'boss' : 'attack');
    combatCooldown = 0.45;

    if (enemy.health <= 0) {
      final prevLevel = playerStats.level;
      playerStats.gainExperience(
        enemy.type == EnemyType.boss ? 500 : 25 + currentFloor * 8,
      );
      if (playerStats.level > prevLevel) {
        _spawnLevelUpParticles();
      }

      if (activeQuest?.type == QuestType.killEnemies) {
        activeQuest!.progress = min(activeQuest!.target, activeQuest!.progress + 1);
        if (activeQuest!.progress >= activeQuest!.target && !activeQuest!.complete) {
          activeQuest!.complete = true;
          _spawnQuestCompleteParticles();
        }
      }

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

  void _checkChestPickup() {
    final playerTile = Offset(playerPosition.dx.toInt().toDouble(), playerPosition.dy.toInt().toDouble());
    if (chests.contains(playerTile)) {
      chests.remove(playerTile);
      audioManager.playSound('lever');
      _spawnQuestCompleteParticles();

      final loot = LootSystem().generateLoot();
      inventorySystem.addItem(loot);

      final prevLevel = playerStats.level;
      playerStats.gainExperience(15 + currentFloor * 5);
      if (playerStats.level > prevLevel) {
        _spawnLevelUpParticles();
      }

      if (activeQuest?.type == QuestType.collectItems) {
        _lootChestsOpened++;
        activeQuest!.progress = min(activeQuest!.target, _lootChestsOpened);
        if (activeQuest!.progress >= activeQuest!.target && !activeQuest!.complete) {
          activeQuest!.complete = true;
          _spawnQuestCompleteParticles();
        }
      }
    }
  }

  void _checkFloorTransition() {
    final currentTile = dungeon.getTile(
      playerPosition.dx.toInt(),
      playerPosition.dy.toInt(),
    );
    if (currentTile == TileType.stairDown && !_isFinalFloor) {
      if (!hasKey) {
        audioManager.playSound('blocked');
        floorBannerTimer = 2.0;
        return;
      }

      if (activeQuest != null && !activeQuest!.complete) {
        audioManager.playSound('blocked');
        floorBannerTimer = 2.5;
        return;
      }

      audioManager.playSound('floor');
      _nextFloor();
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
        stepX = direction == 0 ? 1 : direction == 1 ? -1 : 0;
        stepY = direction == 2 ? 1 : direction == 3 ? -1 : 0;
      }

      int targetX = enemy.x.toInt() + stepX;
      int targetY = enemy.y.toInt() + stepY;
      if (stepX == 0 && stepY == 0) continue;
      if (!_canMoveTo(targetX, targetY)) continue;
      if (targetX == playerPosition.dx.toInt() &&
          targetY == playerPosition.dy.toInt()) { continue; }
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
    completedLevels.value = {...completedLevels.value, currentFloor};
    gameState.value = GameState.levelComplete;
    overlays.add('LevelComplete');
  }

  void goToLevelSelection() {
    overlays.clear();
    gameState.value = GameState.levelSelection;
  }

  void loadLevel(int level) {
    currentFloor = level;
    _regenerateDungeon();
    overlays.clear();
    gameState.value = GameState.playing;
  }

  void startNextLevel() {
    if (currentFloor < totalLevels) {
      loadLevel(currentFloor + 1);
    } else {
      goToLevelSelection();
    }
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
    _spawnChests();
    _generateFloorQuest();
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
    _drawChests(canvas);
    _drawTrailDots(canvas);
    _drawEnemies(canvas);
    _drawPlayer(canvas);
    canvas.restore();

    _drawHud(canvas);
    _drawFloorBanner(canvas);
    _drawDarkness(canvas);
  }

  void _drawDarkness(Canvas canvas) {
    if (gameState.value != GameState.playing) return;

    final baseRadius = size.x * 0.45;
    final floorDifficulty = (currentFloor - 1) / (maxFloor - 1);
    final visibilityRadius = baseRadius * (1.0 - floorDifficulty * 0.5);

    // Calculate player position on screen
    final scale = min(size.x / _worldWidth, size.y / _worldHeight);
    final offsetX = (size.x - (_worldWidth * scale)) / 2;
    final offsetY = (size.y - (_worldHeight * scale)) / 2;
    final playerScreenPos = Offset(
      offsetX + (playerPosition.dx * tileSize + tileSize / 2) * scale,
      offsetY + (playerPosition.dy * tileSize + tileSize / 2) * scale,
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.2 + floorDifficulty * 0.4),
            Colors.black.withValues(alpha: 0.6 + floorDifficulty * 0.3),
            Colors.black,
          ],
          stops: const [0.0, 0.4, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: playerScreenPos, radius: visibilityRadius)),
    );
  }

  void _drawTrailDots(Canvas canvas) {
    for (final dot in trailDots) {
      dot.render(canvas);
    }
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
            paint.color = (hasKey && (activeQuest == null || activeQuest!.complete)) || _isFinalFloor
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
        } else if (tile == TileType.stairDown && (!hasKey || (activeQuest != null && !activeQuest!.complete)) && !_isFinalFloor) {
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
    final pulse = 1 + sin(elapsedTime * 6) * 0.05;
    final size = tileSize * 0.9 * pulse;
    final position = Vector2(
      playerPosition.dx * tileSize + (tileSize - size) / 2,
      playerPosition.dy * tileSize + (tileSize - size) / 2,
    );

    // Draw glow
    final activeColor = Colors.blue.withValues(alpha: 0.3);
    final glowPaint = Paint()
      ..color = activeColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(
      Offset(position.x + size / 2, position.y + size / 2),
      size * 0.8,
      glowPaint,
    );

    playerSprite.render(
      canvas,
      position: position,
      size: Vector2(size, size),
    );
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

  void _drawChests(Canvas canvas) {
    for (final chest in chests) {
      final position = Offset(
        chest.dx * tileSize + tileSize / 2,
        chest.dy * tileSize + tileSize / 2,
      );
      final rect = Rect.fromCenter(center: position, width: tileSize * 0.55, height: tileSize * 0.45);
      canvas.drawRect(
        rect,
        Paint()..color = const Color(0xFF8B5A2B), // Brown
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = const Color(0xFFFFD700) // Gold border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(position, tileSize * 0.08, Paint()..color = const Color(0xFFFFD700));
    }
  }

  void _drawEnemies(Canvas canvas) {
    for (final enemy in enemies) {
      final pulse = 1 + sin(elapsedTime * 4 + enemy.x + enemy.y) * 0.06;
      final sprite = enemySprites[enemy.type];
      if (sprite == null) continue;

      final radius = _enemyRadius(enemy.type);
      final size = tileSize * radius * 2 * pulse;
      final position = Vector2(
        enemy.x * tileSize + (tileSize - size) / 2,
        enemy.y * tileSize + (tileSize - size) / 2,
      );

      // Draw shadow
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(position.x + size / 2, position.y + size * 0.9),
          width: size * 0.6,
          height: size * 0.2,
        ),
        Paint()..color = Colors.black26,
      );

      sprite.render(
        canvas,
        position: position,
        size: Vector2(size, size),
      );

      // Health bar
      if (enemy.health < _enemyHealth(enemy.type)) {
        final healthPercent = enemy.health / _enemyHealth(enemy.type);
        final barWidth = size * 0.8;
        final barHeight = 2.0;
        final barX = position.x + (size - barWidth) / 2;
        final barY = position.y - 4;

        canvas.drawRect(
          Rect.fromLTWH(barX, barY, barWidth, barHeight),
          Paint()..color = Colors.red.withValues(alpha: 0.5),
        );
        canvas.drawRect(
          Rect.fromLTWH(barX, barY, barWidth * healthPercent, barHeight),
          Paint()..color = Colors.green,
        );
      }
    }
  }

  double _enemyRadius(EnemyType type) {
    return type == EnemyType.boss ? 0.62 : 0.35;
  }

  void _drawHud(Canvas canvas) {
    final hudMargin = 14.0;
    final hudPadding = 10.0;
    final lineHeight = 15.0;
    final panelWidth = min(130.0, size.x - hudMargin * 2);
    final panelHeight = 244.0;
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

    if (activeQuest != null) {
      debugText.render(
        canvas,
        'Qst: ${activeQuest!.progress}/${activeQuest!.target}',
        Vector2(textX, textY),
      );
      textY += lineHeight;
    }

    final objective = _isFinalFloor
        ? gameWon
            ? 'Boss defeated'
            : 'Objective: defeat boss'
        : activeQuest != null && !activeQuest!.complete
        ? 'Objective: complete quest'
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

    final currentTile = dungeon.getTile(
      playerPosition.dx.toInt(),
      playerPosition.dy.toInt(),
    );

    String title;
    if (gameWon) {
      title = 'Dungeon Cleared!';
    } else if (_isFinalFloor) {
      title = 'Floor 10: Boss Chamber';
    } else if (currentTile == TileType.stairDown) {
      if (!hasKey) {
        title = 'Portal requires key!';
      } else if (activeQuest != null && !activeQuest!.complete) {
        title = 'Quest incomplete! ${activeQuest!.progress}/${activeQuest!.target}';
      } else {
        title = 'Portal unlocked! Solve rune';
      }
    } else if (playerStats.health <= 0) {
      title = 'Rune failed! Took damage';
    } else {
      title = activeQuest != null
          ? '${activeQuest!.title}: ${activeQuest!.description}'
          : 'Entered Floor $currentFloor';
    }

    bannerText.render(
      canvas,
      title,
      Vector2(size.x / 2 - title.length * 5.8, 38),
    );
  }

  void _spawnMoveParticles(Offset oldTilePos) {
    final centerPos = Offset(
      oldTilePos.dx * tileSize + tileSize / 2,
      oldTilePos.dy * tileSize + tileSize / 2,
    );
    final random = Random();
    const googleColors = [
      Color(0xFF4285F4), // Blue
      Color(0xFFEA4335), // Red
      Color(0xFFFBBC05), // Yellow
      Color(0xFF34A853), // Green
    ];

    for (int i = 0; i < 8; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final speed = 15.0 + random.nextDouble() * 30.0;
      final velocity = Offset(cos(angle) * speed, sin(angle) * speed);
      final color = googleColors[random.nextInt(googleColors.length)];
      final life = 0.4 + random.nextDouble() * 0.4;
      final maxRadius = tileSize * (0.18 + random.nextDouble() * 0.12);

      trailDots.add(AnimatedDot(
        position: centerPos,
        velocity: velocity,
        color: color,
        life: life,
        maxRadius: maxRadius,
        type: ParticleType.trail,
      ));
    }
  }

  void _spawnQuestCompleteParticles() {
    final centerPos = Offset(
      playerPosition.dx * tileSize + tileSize / 2,
      playerPosition.dy * tileSize + tileSize / 2,
    );
    final random = Random();
    for (int i = 0; i < 20; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final speed = 30.0 + random.nextDouble() * 50.0;
      final velocity = Offset(cos(angle) * speed, sin(angle) * speed);
      final color = const Color(0xFFFFD700); // Gold
      final life = 0.6 + random.nextDouble() * 0.5;
      final maxRadius = tileSize * (0.15 + random.nextDouble() * 0.15);

      trailDots.add(AnimatedDot(
        position: centerPos,
        velocity: velocity,
        color: color,
        life: life,
        maxRadius: maxRadius,
        type: ParticleType.questComplete,
      ));
    }
  }

  void _spawnLevelUpParticles() {
    final centerPos = Offset(
      playerPosition.dx * tileSize + tileSize / 2,
      playerPosition.dy * tileSize + tileSize / 2,
    );
    final random = Random();
    const googleColors = [
      Color(0xFF4285F4), // Blue
      Color(0xFFEA4335), // Red
      Color(0xFFFBBC05), // Yellow
      Color(0xFF34A853), // Green
    ];
    for (int i = 0; i < 24; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final speed = 10.0 + random.nextDouble() * 20.0;
      final velocity = Offset(cos(angle) * speed, -40.0 - random.nextDouble() * 30.0);
      final color = googleColors[random.nextInt(googleColors.length)];
      final life = 0.8 + random.nextDouble() * 0.6;
      final maxRadius = tileSize * (0.2 + random.nextDouble() * 0.2);

      trailDots.add(AnimatedDot(
        position: centerPos,
        velocity: velocity,
        color: color,
        life: life,
        maxRadius: maxRadius,
        type: ParticleType.levelUp,
      ));
    }
  }

  void _spawnDamageParticles(Offset tilePos) {
    final centerPos = Offset(
      tilePos.dx * tileSize + tileSize / 2,
      tilePos.dy * tileSize + tileSize / 2,
    );
    final random = Random();
    for (int i = 0; i < 15; i++) {
      final angle = -pi / 4 - random.nextDouble() * pi / 2;
      final speed = 40.0 + random.nextDouble() * 60.0;
      final velocity = Offset(cos(angle) * speed, sin(angle) * speed);
      final color = const Color(0xFFEF4444); // Red
      final life = 0.3 + random.nextDouble() * 0.4;
      final maxRadius = tileSize * (0.12 + random.nextDouble() * 0.12);

      trailDots.add(AnimatedDot(
        position: centerPos,
        velocity: velocity,
        color: color,
        life: life,
        maxRadius: maxRadius,
        type: ParticleType.damage,
      ));
    }
  }

  void _spawnAttackParticles(Offset oldTilePos, Offset targetTilePos) {
    final startPos = Offset(
      oldTilePos.dx * tileSize + tileSize / 2,
      oldTilePos.dy * tileSize + tileSize / 2,
    );
    final targetPos = Offset(
      targetTilePos.dx * tileSize + tileSize / 2,
      targetTilePos.dy * tileSize + tileSize / 2,
    );
    final diff = targetPos - startPos;
    final angle = atan2(diff.dy, diff.dx);
    final random = Random();

    for (int i = 0; i < 12; i++) {
      final spreadAngle = angle + (random.nextDouble() - 0.5) * pi / 3;
      final speed = 80.0 + random.nextDouble() * 80.0;
      final velocity = Offset(cos(spreadAngle) * speed, sin(spreadAngle) * speed);
      final color = const Color(0xFFF97316); // Orange/Slash
      final life = 0.15 + random.nextDouble() * 0.2;
      final maxRadius = tileSize * (0.2 + random.nextDouble() * 0.15);

      trailDots.add(AnimatedDot(
        position: startPos,
        velocity: velocity,
        color: color,
        life: life,
        maxRadius: maxRadius,
        type: ParticleType.attack,
      ));
    }
  }
}

enum ParticleType {
  trail,
  questComplete,
  levelUp,
  damage,
  attack,
}

class AnimatedDot {
  Offset position;
  Offset velocity;
  final Color color;
  double life;
  final double maxLife;
  final double maxRadius;
  final ParticleType type;

  AnimatedDot({
    required this.position,
    required this.velocity,
    required this.color,
    required this.life,
    required this.maxRadius,
    this.type = ParticleType.trail,
  }) : maxLife = life;

  void update(double dt) {
    switch (type) {
      case ParticleType.trail:
        position += velocity * dt;
        break;
      case ParticleType.questComplete:
        velocity = Offset(velocity.dx * 0.9, velocity.dy - 10.0 * dt);
        position += velocity * dt;
        break;
      case ParticleType.levelUp:
        velocity = Offset(velocity.dx + sin(life * 10) * 15, velocity.dy - 20.0 * dt);
        position += velocity * dt;
        break;
      case ParticleType.damage:
        velocity = Offset(velocity.dx * 0.95, velocity.dy + 80.0 * dt);
        position += velocity * dt;
        break;
      case ParticleType.attack:
        position += velocity * dt;
        break;
    }
    life -= dt;
  }

  void render(Canvas canvas) {
    if (life <= 0) return;
    final progress = life / maxLife;
    final paint = Paint()
      ..color = color.withValues(alpha: progress * 0.85)
      ..style = PaintingStyle.fill;

    if (type == ParticleType.levelUp) {
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2.0;
      canvas.drawCircle(position, maxRadius * (1.5 - progress), paint);
    } else if (type == ParticleType.attack) {
      final end = position + velocity * (0.05 * progress);
      canvas.drawLine(
        position,
        end,
        Paint()
          ..color = color.withValues(alpha: progress)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    } else {
      canvas.drawCircle(position, maxRadius * progress, paint);
    }
  }
}

