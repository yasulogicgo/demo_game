class Companion {
  final String id;
  final String name;
  final String type;
  int level;

  Companion({
    required this.id,
    required this.name,
    required this.type,
    this.level = 1,
  });
}

class CompanionSystem {
  final List<Companion> companions = [];

  void addCompanion(Companion companion) {
    companions.add(companion);
  }

  void levelUpCompanion(String companionId) {
    final companion = companions.firstWhere((c) => c.id == companionId);
    companion.level += 1;
  }
}
