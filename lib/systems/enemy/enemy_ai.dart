import '../../data/models/enemy.dart';

class EnemyAI {
  EnemyState getNextState(
    Enemy enemy,
    EnemyState currentState,
    bool playerNearby,
  ) {
    if (!playerNearby) {
      return EnemyState.patrol;
    }
    if (enemy.health < 10) {
      return EnemyState.flee;
    }
    return EnemyState.chase;
  }

  void updateEnemy(Enemy enemy, double dt) {
    // TODO: implement pathfinding and behavior transitions.
  }
}
