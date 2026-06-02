import 'dart:math';
import 'dart:ui';
import '../../data/models/dungeon_data.dart';
import '../../data/models/room.dart';
import 'bsp_leaf.dart';

class DungeonGenerator {
  final int width;
  final int height;
  final int maxLeafSize;
  final int floor;

  DungeonGenerator({
    required this.width,
    required this.height,
    this.maxLeafSize = 20,
    this.floor = 1,
  });

  DungeonData generate() {
    List<BSPLeaf> leaves = [];
    BSPLeaf root = BSPLeaf(0, 0, width, height);
    leaves.add(root);

    bool didSplit = true;
    while (didSplit) {
      didSplit = false;
      for (int i = 0; i < leaves.length; i++) {
        BSPLeaf l = leaves[i];
        if (l.leftChild == null && l.rightChild == null) {
          if (l.width > maxLeafSize ||
              l.height > maxLeafSize ||
              Random().nextDouble() > 0.25) {
            if (l.split()) {
              leaves.add(l.leftChild!);
              leaves.add(l.rightChild!);
              didSplit = true;
            }
          }
        }
      }
    }

    root.createRooms();

    List<List<TileType>> grid = List.generate(
      height,
      (_) => List.generate(width, (_) => TileType.wall),
    );

    List<Room> rooms = root.getRooms();
    for (Room room in rooms) {
      for (int y = room.y; y < room.y + room.height; y++) {
        for (int x = room.x; x < room.x + room.width; x++) {
          grid[y][x] = TileType.floor;
        }
      }
    }

    List<Rect> corridors = root.getCorridors();
    for (Rect corridor in corridors) {
      for (int y = corridor.top.toInt(); y < corridor.bottom.toInt(); y++) {
        for (int x = corridor.left.toInt(); x < corridor.right.toInt(); x++) {
          grid[y][x] = TileType.floor;
        }
      }
    }

    // Place stairs
    if (rooms.length >= 2) {
      final lastRoom = rooms.last;
      final stairDownX = lastRoom.x + lastRoom.width ~/ 2;
      final stairDownY = lastRoom.y + lastRoom.height ~/ 2;
      if (stairDownX >= 0 &&
          stairDownX < width &&
          stairDownY >= 0 &&
          stairDownY < height) {
        grid[stairDownY][stairDownX] = TileType.stairDown;
      }

      if (floor > 1 && rooms.length >= 3) {
        final stairUpRoom = rooms[rooms.length ~/ 2];
        final stairUpX = stairUpRoom.x + stairUpRoom.width ~/ 2;
        final stairUpY = stairUpRoom.y + stairUpRoom.height ~/ 2;
        if (stairUpX >= 0 &&
            stairUpX < width &&
            stairUpY >= 0 &&
            stairUpY < height) {
          grid[stairUpY][stairUpX] = TileType.stairUp;
        }
      }
    }

    return DungeonData(width: width, height: height, grid: grid, rooms: rooms);
  }
}
