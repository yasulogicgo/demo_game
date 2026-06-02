import '../../data/models/item.dart';

class LootSystem {
  Item generateLoot() {
    return Item(
      id: 'loot_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Basic Sword',
      type: ItemType.weapon,
      rarity: ItemRarity.common,
      stats: {'damage': 3},
      value: 10,
    );
  }

  void dropLoot(String tileKey) {
    // TODO: integrate with tile and entity placement systems.
  }

  double calculateDropRate(ItemRarity rarity) {
    switch (rarity) {
      case ItemRarity.common:
        return 0.65;
      case ItemRarity.uncommon:
        return 0.20;
      case ItemRarity.rare:
        return 0.08;
      case ItemRarity.epic:
        return 0.04;
      case ItemRarity.legendary:
        return 0.02;
      case ItemRarity.mythic:
        return 0.01;
    }
  }
}
