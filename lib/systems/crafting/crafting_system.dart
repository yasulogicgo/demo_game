import '../../data/models/item.dart';

class CraftingSystem {
  final Map<String, Map<String, int>> recipes = {
    'iron_sword': {'iron': 2, 'wood': 1},
    'magic_potion': {'potion': 1, 'gem': 1},
  };

  bool canCraft(String recipeId, Map<String, int> inventoryCounts) {
    final recipe = recipes[recipeId];
    if (recipe == null) return false;
    return recipe.entries.every(
      (entry) =>
          inventoryCounts[entry.key] != null &&
          inventoryCounts[entry.key]! >= entry.value,
    );
  }

  Item craft(String recipeId) {
    if (recipeId == 'iron_sword') {
      return Item(
        id: 'iron_sword',
        name: 'Iron Sword',
        type: ItemType.weapon,
        rarity: ItemRarity.uncommon,
        stats: {'damage': 8},
        value: 40,
      );
    }
    if (recipeId == 'magic_potion') {
      return Item(
        id: 'magic_potion',
        name: 'Magic Potion',
        type: ItemType.potion,
        rarity: ItemRarity.rare,
        stats: {'heal': 25},
        value: 60,
      );
    }
    throw StateError('Recipe not found');
  }
}
