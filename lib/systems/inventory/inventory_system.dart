import '../../data/models/item.dart';

class InventorySystem {
  final List<Item> items = [];
  final int capacity;

  InventorySystem({this.capacity = 30});

  bool addItem(Item item) {
    if (items.length >= capacity) return false;
    items.add(item);
    return true;
  }

  bool removeItem(String itemId) {
    final int initialLength = items.length;
    items.removeWhere((item) => item.id == itemId);
    return items.length < initialLength;
  }

  void sortInventory() {
    items.sort((a, b) {
      final rarityOrder = a.rarity.index.compareTo(b.rarity.index);
      if (rarityOrder != 0) return rarityOrder;
      return a.name.compareTo(b.name);
    });
  }

  Item? findItem(String itemId) {
    for (final item in items) {
      if (item.id == itemId) {
        return item;
      }
    }
    return null;
  }
}
