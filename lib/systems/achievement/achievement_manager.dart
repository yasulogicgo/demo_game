import '../../data/models/achievement.dart';

class AchievementManager {
  final List<Achievement> achievements = [];

  void registerAchievement(Achievement achievement) {
    achievements.add(achievement);
  }

  void unlock(String achievementId) {
    final achievement = achievements.firstWhere(
      (item) => item.id == achievementId,
      orElse: () => throw StateError('Achievement not found'),
    );
    achievement.unlocked = true;
  }

  List<Achievement> get unlockedAchievements =>
      achievements.where((achievement) => achievement.unlocked).toList();
}
