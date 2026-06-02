import 'room.dart';

enum TileType {
  wall,
  floor,
  door,
  stairUp,
  stairDown,
}

class DungeonData {
  final int width;
  final int height;
  final List<List<TileType>> grid;
  final List<Room> rooms;

  DungeonData({
    required this.width,
    required this.height,
    required this.grid,
    required this.rooms,
  });

  TileType getTile(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) {
      return TileType.wall;
    }
    return grid[y][x];
  }

  void setTile(int x, int y, TileType type) {
    if (x >= 0 && x < width && y >= 0 && y < height) {
      grid[y][x] = type;
    }
  }
}
