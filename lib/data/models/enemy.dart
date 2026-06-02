enum EnemyType { goblin, skeleton, slime, spider, mage, knight, boss }

enum EnemyState { idle, patrol, chase, attack, flee, dead }

class Enemy {
  final String id;
  final EnemyType type;
  int health;
  final int damage;
  final int defense;
  double x;
  double y;

  Enemy({
    required this.id,
    required this.type,
    required this.health,
    required this.damage,
    required this.defense,
    this.x = 0,
    this.y = 0,
  });
}
