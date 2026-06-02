import '../../data/models/equipment.dart';

class EquipmentManager {
  final Map<EquipmentSlot, Equipment?> equipped = {
    EquipmentSlot.helmet: null,
    EquipmentSlot.chest: null,
    EquipmentSlot.gloves: null,
    EquipmentSlot.boots: null,
    EquipmentSlot.weapon: null,
    EquipmentSlot.shield: null,
    EquipmentSlot.ring: null,
    EquipmentSlot.amulet: null,
  };

  bool equip(Equipment equipment) {
    equipped[equipment.slot] = equipment;
    return true;
  }

  Equipment? unequip(EquipmentSlot slot) {
    final removed = equipped[slot];
    equipped[slot] = null;
    return removed;
  }

  int calculateBonus(String stat) {
    return equipped.values
        .whereType<Equipment>()
        .map((item) => item.stats[stat] ?? 0)
        .fold(0, (sum, bonus) => sum + bonus);
  }
}
