# Dungeon Legends: The Forgotten Realm

A Flutter + Flame roguelike dungeon crawler framework.

## Project Concept

This repository now includes a reusable architecture for a procedurally generated dungeon crawler:

- BSP-based dungeon generation
- Player stats and leveling
- Inventory and equipment systems
- Loot generation and rarity management
- Combat and status effect scaffolding
- Skill, quest, achievement, shop, crafting, companion, and minimap systems
- Audio and save manager placeholders for future expansion

## Structure

- `lib/core/game/` — game entry point and main Flame game class
- `lib/components/player/` — player stats and data models
- `lib/data/models/` — generic item, equipment, quest, achievement, and enemy models
- `lib/procedural/dungeon_generator/` — dungeon generation system using BSP
- `lib/systems/` — reusable gameplay subsystems
- `lib/core/audio/` — audio management scaffolding
- `lib/core/save/` — save/load scaffolding

## Getting Started

Run the app with:

```bash
flutter run
```

The current build renders a starter dungeon layout and a player marker, and provides a foundation for adding movement, enemies, loot drops, boss rooms, and additional systems.

## Next Steps

- Add input handling and player movement
- Implement enemy AI and pathfinding
- Add item pickups, shops, and crafting
- Build a HUD, minimap UI, and skill tree screens
- Persist progress using shared_preferences, Hive, or Isar
