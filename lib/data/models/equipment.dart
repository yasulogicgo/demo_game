import 'item.dart';

enum EquipmentSlot {
  helmet,
  chest,
  gloves,
  boots,
  weapon,
  shield,
  ring,
  amulet,
}

class Equipment {
  final String id;
  final String name;
  final EquipmentSlot slot;
  final ItemRarity rarity;
  final Map<String, int> stats;

  Equipment({
    required this.id,
    required this.name,
    required this.slot,
    required this.rarity,
    this.stats = const {},
  });
}
