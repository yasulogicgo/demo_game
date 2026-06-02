class Achievement {
  final String id;
  final String title;
  final String description;
  bool unlocked;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    this.unlocked = false,
  });
}
