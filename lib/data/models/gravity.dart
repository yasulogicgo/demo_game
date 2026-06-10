/// Represents which direction gravity is currently pulling.
enum GravityDirection { down, up, left, right }

/// Extension helpers for GravityDirection.
extension GravityDirectionExt on GravityDirection {
  /// Returns (dx, dy) step unit for the gravity direction.
  (int, int) get delta {
    return switch (this) {
      GravityDirection.down => (0, 1),
      GravityDirection.up => (0, -1),
      GravityDirection.left => (-1, 0),
      GravityDirection.right => (1, 0),
    };
  }

  /// Returns the next clockwise gravity direction.
  GravityDirection get clockwise {
    return switch (this) {
      GravityDirection.down => GravityDirection.left,
      GravityDirection.left => GravityDirection.up,
      GravityDirection.up => GravityDirection.right,
      GravityDirection.right => GravityDirection.down,
    };
  }

  String get label {
    return switch (this) {
      GravityDirection.down => '▼ DOWN',
      GravityDirection.up => '▲ UP',
      GravityDirection.left => '◀ LEFT',
      GravityDirection.right => '▶ RIGHT',
    };
  }
}

/// Represents a gravity zone placed at a specific tile in the dungeon.
/// When the player steps on this tile, current gravity changes to [direction].
class GravityZoneData {
  final int x;
  final int y;
  final GravityDirection direction;

  const GravityZoneData({
    required this.x,
    required this.y,
    required this.direction,
  });

  @override
  bool operator ==(Object other) =>
      other is GravityZoneData && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}
