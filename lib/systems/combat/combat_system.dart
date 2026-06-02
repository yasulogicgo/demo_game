import '../../components/player/player_stats.dart';
import '../../data/models/enemy.dart';

enum StatusEffect { poison, burn, freeze, bleed, stun, curse }

class CombatSystem {
  int calculateDamage(PlayerStats attacker, PlayerStats defender) {
    final baseDamage = attacker.strength;
    final defenseReduction = defender.defense ~/ 2;
    return (baseDamage - defenseReduction).clamp(1, baseDamage);
  }

  int calculateEnemyDamage(Enemy attacker, PlayerStats defender) {
    final baseDamage = attacker.damage;
    final defenseReduction = defender.defense ~/ 2;
    return (baseDamage - defenseReduction).clamp(1, baseDamage);
  }

  bool tryCriticalHit(PlayerStats attacker) {
    final roll = attacker.luck + attacker.agility;
    return roll > 20;
  }

  void applyStatusEffect(StatusEffect effect, PlayerStats target) {
    switch (effect) {
      case StatusEffect.poison:
      case StatusEffect.burn:
      case StatusEffect.bleed:
        target.takeDamage(2);
        break;
      case StatusEffect.freeze:
      case StatusEffect.stun:
      case StatusEffect.curse:
        // placeholder for future effect duration behavior
        break;
    }
  }
}
