import 'dart:math';
import 'dart:ui';
import '../../data/models/room.dart';

class BSPLeaf {
  static const int minLeafSize = 10;

  final int x;
  final int y;
  final int width;
  final int height;

  BSPLeaf? leftChild;
  BSPLeaf? rightChild;
  Room? room;
  List<Rect> corridors = [];

  BSPLeaf(this.x, this.y, this.width, this.height);

  bool split() {
    if (leftChild != null || rightChild != null) return false;

    bool splitH = Random().nextBool();
    if (width > height && width / height >= 1.25) {
      splitH = false;
    } else if (height > width && height / width >= 1.25) {
      splitH = true;
    }

    int max = (splitH ? height : width) - minLeafSize;
    if (max <= minLeafSize) return false;

    int split = Random().nextInt(max - minLeafSize) + minLeafSize;

    if (splitH) {
      leftChild = BSPLeaf(x, y, width, split);
      rightChild = BSPLeaf(x, y + split, width, height - split);
    } else {
      leftChild = BSPLeaf(x, y, split, height);
      rightChild = BSPLeaf(x + split, y, width - split, height);
    }

    return true;
  }

  void createRooms() {
    if (leftChild != null || rightChild != null) {
      leftChild?.createRooms();
      rightChild?.createRooms();

      if (leftChild != null && rightChild != null) {
        createCorridor(leftChild!, rightChild!);
      }
    } else {
      final random = Random();
      final roomWidth = random.nextInt(width - 4) + 3;
      final roomHeight = random.nextInt(height - 4) + 3;
      final maxRoomX = width - roomWidth - 2;
      final maxRoomY = height - roomHeight - 2;
      final roomX = maxRoomX > 0 ? random.nextInt(maxRoomX) + 1 : 1;
      final roomY = maxRoomY > 0 ? random.nextInt(maxRoomY) + 1 : 1;

      room = Room(
        x: x + roomX,
        y: y + roomY,
        width: roomWidth,
        height: roomHeight,
      );
    }
  }

  void createCorridor(BSPLeaf left, BSPLeaf right) {
    Room? leftRoom = left.getRoom();
    Room? rightRoom = right.getRoom();

    if (leftRoom == null || rightRoom == null) return;

    Point p1 = Point(
      Random().nextInt(leftRoom.width) + leftRoom.x,
      Random().nextInt(leftRoom.height) + leftRoom.y,
    );
    Point p2 = Point(
      Random().nextInt(rightRoom.width) + rightRoom.x,
      Random().nextInt(rightRoom.height) + rightRoom.y,
    );

    int w = p2.x.toInt() - p1.x.toInt();
    int h = p2.y.toInt() - p1.y.toInt();

    if (w < 0) {
      if (h < 0) {
        if (Random().nextBool()) {
          corridors.add(
            Rect.fromLTWH(
              p2.x.toDouble(),
              p1.y.toDouble(),
              w.abs().toDouble() + 1,
              1,
            ),
          );
          corridors.add(
            Rect.fromLTWH(
              p2.x.toDouble(),
              p2.y.toDouble(),
              1,
              h.abs().toDouble() + 1,
            ),
          );
        } else {
          corridors.add(
            Rect.fromLTWH(
              p2.x.toDouble(),
              p2.y.toDouble(),
              w.abs().toDouble() + 1,
              1,
            ),
          );
          corridors.add(
            Rect.fromLTWH(
              p1.x.toDouble(),
              p2.y.toDouble(),
              1,
              h.abs().toDouble() + 1,
            ),
          );
        }
      } else if (h > 0) {
        if (Random().nextBool()) {
          corridors.add(
            Rect.fromLTWH(
              p2.x.toDouble(),
              p1.y.toDouble(),
              w.abs().toDouble() + 1,
              1,
            ),
          );
          corridors.add(
            Rect.fromLTWH(
              p2.x.toDouble(),
              p1.y.toDouble(),
              1,
              h.abs().toDouble() + 1,
            ),
          );
        } else {
          corridors.add(
            Rect.fromLTWH(
              p2.x.toDouble(),
              p2.y.toDouble(),
              w.abs().toDouble() + 1,
              1,
            ),
          );
          corridors.add(
            Rect.fromLTWH(
              p1.x.toDouble(),
              p1.y.toDouble(),
              1,
              h.abs().toDouble() + 1,
            ),
          );
        }
      } else {
        corridors.add(
          Rect.fromLTWH(
            p2.x.toDouble(),
            p2.y.toDouble(),
            w.abs().toDouble() + 1,
            1,
          ),
        );
      }
    } else if (w > 0) {
      if (h < 0) {
        if (Random().nextBool()) {
          corridors.add(
            Rect.fromLTWH(
              p1.x.toDouble(),
              p2.y.toDouble(),
              w.abs().toDouble() + 1,
              1,
            ),
          );
          corridors.add(
            Rect.fromLTWH(
              p1.x.toDouble(),
              p2.y.toDouble(),
              1,
              h.abs().toDouble() + 1,
            ),
          );
        } else {
          corridors.add(
            Rect.fromLTWH(
              p1.x.toDouble(),
              p1.y.toDouble(),
              w.abs().toDouble() + 1,
              1,
            ),
          );
          corridors.add(
            Rect.fromLTWH(
              p2.x.toDouble(),
              p2.y.toDouble(),
              1,
              h.abs().toDouble() + 1,
            ),
          );
        }
      } else if (h > 0) {
        if (Random().nextBool()) {
          corridors.add(
            Rect.fromLTWH(
              p1.x.toDouble(),
              p1.y.toDouble(),
              w.abs().toDouble() + 1,
              1,
            ),
          );
          corridors.add(
            Rect.fromLTWH(
              p2.x.toDouble(),
              p1.y.toDouble(),
              1,
              h.abs().toDouble() + 1,
            ),
          );
        } else {
          corridors.add(
            Rect.fromLTWH(
              p1.x.toDouble(),
              p2.y.toDouble(),
              w.abs().toDouble() + 1,
              1,
            ),
          );
          corridors.add(
            Rect.fromLTWH(
              p1.x.toDouble(),
              p1.y.toDouble(),
              1,
              h.abs().toDouble() + 1,
            ),
          );
        }
      } else {
        corridors.add(
          Rect.fromLTWH(
            p1.x.toDouble(),
            p1.y.toDouble(),
            w.abs().toDouble() + 1,
            1,
          ),
        );
      }
    } else {
      if (h < 0) {
        corridors.add(
          Rect.fromLTWH(
            p2.x.toDouble(),
            p2.y.toDouble(),
            1,
            h.abs().toDouble() + 1,
          ),
        );
      } else if (h > 0) {
        corridors.add(
          Rect.fromLTWH(
            p1.x.toDouble(),
            p1.y.toDouble(),
            1,
            h.abs().toDouble() + 1,
          ),
        );
      }
    }
  }

  Room? getRoom() {
    if (room != null) return room;
    Room? leftRoom = leftChild?.getRoom();
    Room? rightRoom = rightChild?.getRoom();

    if (leftRoom == null && rightRoom == null) return null;
    if (leftRoom == null) return rightRoom;
    if (rightRoom == null) return leftRoom;

    return Random().nextBool() ? leftRoom : rightRoom;
  }

  List<Rect> getCorridors() {
    List<Rect> allCorridors = List.from(corridors);
    if (leftChild != null) allCorridors.addAll(leftChild!.getCorridors());
    if (rightChild != null) allCorridors.addAll(rightChild!.getCorridors());
    return allCorridors;
  }

  List<Room> getRooms() {
    List<Room> allRooms = [];
    if (room != null) {
      allRooms.add(room!);
    } else {
      if (leftChild != null) allRooms.addAll(leftChild!.getRooms());
      if (rightChild != null) allRooms.addAll(rightChild!.getRooms());
    }
    return allRooms;
  }
}
