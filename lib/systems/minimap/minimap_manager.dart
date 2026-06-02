import '../../data/models/dungeon_data.dart';

class MinimapManager {
  final List<List<bool>> visibility;

  MinimapManager(int width, int height)
    : visibility = List.generate(
        height,
        (_) => List.generate(width, (_) => false),
      );

  void revealTile(int x, int y) {
    if (y >= 0 && y < visibility.length && x >= 0 && x < visibility[y].length) {
      visibility[y][x] = true;
    }
  }

  bool isRevealed(int x, int y) {
    if (y < 0 || y >= visibility.length || x < 0 || x >= visibility[y].length) {
      return false;
    }
    return visibility[y][x];
  }

  void revealRoomArea(DungeonData dungeonData) {
    for (final room in dungeonData.rooms) {
      for (int y = room.y; y < room.y + room.height; y++) {
        for (int x = room.x; x < room.x + room.width; x++) {
          revealTile(x, y);
        }
      }
    }
  }
}
