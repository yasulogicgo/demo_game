import 'dart:ui';

class Room {
  final int x;
  final int y;
  final int width;
  final int height;

  Room({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  Rect get rect => Rect.fromLTWH(
    x.toDouble(),
    y.toDouble(),
    width.toDouble(),
    height.toDouble(),
  );

  Offset get center =>
      Offset((x + width / 2).floorToDouble(), (y + height / 2).floorToDouble());

  bool intersects(Room other) {
    return x < other.x + other.width &&
        x + width > other.x &&
        y < other.y + other.height &&
        y + height > other.y;
  }
}
