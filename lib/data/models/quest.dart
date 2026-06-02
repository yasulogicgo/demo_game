enum QuestType { killEnemies, collectItems, defeatBoss, exploreRooms }

class Quest {
  final String id;
  final String title;
  final QuestType type;
  final String description;
  final int target;
  int progress;
  bool complete;

  Quest({
    required this.id,
    required this.title,
    required this.type,
    required this.description,
    this.target = 1,
    this.progress = 0,
    this.complete = false,
  });
}
