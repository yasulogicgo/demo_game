enum SkillCategory { warrior, mage, rogue, hunter }

class Skill {
  final String id;
  final String name;
  final SkillCategory category;
  final String description;
  final int cost;
  final int levelRequired;

  Skill({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    this.cost = 1,
    this.levelRequired = 1,
  });
}
