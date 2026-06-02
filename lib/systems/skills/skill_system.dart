import '../../data/models/skill.dart';

class SkillSystem {
  final List<Skill> availableSkills = [];
  final List<Skill> unlockedSkills = [];

  void registerSkill(Skill skill) {
    availableSkills.add(skill);
  }

  bool unlockSkill(String skillId, int playerLevel) {
    final skill = availableSkills.firstWhere(
      (element) => element.id == skillId,
      orElse: () => throw StateError('Skill not found'),
    );
    if (playerLevel >= skill.levelRequired && !unlockedSkills.contains(skill)) {
      unlockedSkills.add(skill);
      return true;
    }
    return false;
  }
}
