class SaveManager {
  Future<void> saveGame(Map<String, dynamic> data) async {
    // TODO: implement persistent save with shared_preferences, Hive, or Isar.
  }

  Future<Map<String, dynamic>> loadGame() async {
    // TODO: restore saved data from disk.
    return {};
  }
}
