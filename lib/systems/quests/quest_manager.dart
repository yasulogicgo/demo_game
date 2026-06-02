import '../../data/models/quest.dart';

class QuestManager {
  final List<Quest> activeQuests = [];

  void addQuest(Quest quest) {
    activeQuests.add(quest);
  }

  void progressQuest(String questId, int amount) {
    final quest = activeQuests.firstWhere(
      (item) => item.id == questId,
      orElse: () => throw StateError('Quest not found'),
    );

    if (!quest.complete) {
      quest.progress += amount;
      if (quest.progress >= quest.target) {
        quest.complete = true;
      }
    }
  }

  List<Quest> get completedQuests =>
      activeQuests.where((quest) => quest.complete).toList();
}
