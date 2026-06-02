import '../../data/models/item.dart';

class ShopSystem {
  final List<Item> inventory = [];

  void buyItem(String itemId) {
    // TODO: purchase item and remove gold from the player.
  }

  void sellItem(Item item) {
    // TODO: add gold and remove item from player inventory.
  }

  void refreshStock() {
    // TODO: regenerate shop offerings.
  }
}
