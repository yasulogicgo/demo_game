enum ItemType {
  weapon,
  armor,
  potion,
  key,
  gem,
  quest,
  ring,
  amulet,
  consumable,
}

enum ItemRarity { common, uncommon, rare, epic, legendary, mythic }

class Item {
  final String id;
  final String name;
  final ItemType type;
  final ItemRarity rarity;
  final Map<String, int> stats;
  final int value;
  final bool stackable;

  Item({
    required this.id,
    required this.name,
    required this.type,
    required this.rarity,
    this.stats = const {},
    this.value = 0,
    this.stackable = false,
  });
}
