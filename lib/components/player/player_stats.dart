class PlayerStats {
  int health;
  int maxHealth;
  int mana;
  int maxMana;
  int strength;
  int defense;
  int agility;
  int luck;
  int level;
  int experience;

  PlayerStats({
    this.health = 100,
    this.maxHealth = 100,
    this.mana = 50,
    this.maxMana = 50,
    this.strength = 10,
    this.defense = 5,
    this.agility = 8,
    this.luck = 4,
    this.level = 1,
    this.experience = 0,
  });

  bool get isAlive => health > 0;

  void takeDamage(int amount) {
    int damage = amount - defense;
    if (damage < 1) damage = 1;
    health = (health - damage).clamp(0, maxHealth);
  }

  void heal(int amount) {
    health = (health + amount).clamp(0, maxHealth);
  }

  void restoreMana(int amount) {
    mana = (mana + amount).clamp(0, maxMana);
  }

  void gainExperience(int amount) {
    experience += amount;
    _checkLevelUp();
  }

  void _checkLevelUp() {
    final nextLevelXp = level * 100;
    while (experience >= nextLevelXp) {
      experience -= nextLevelXp;
      level += 1;
      maxHealth += 10;
      maxMana += 5;
      strength += 2;
      defense += 1;
      agility += 1;
      luck += 1;
      health = maxHealth;
      mana = maxMana;
    }
  }
}
