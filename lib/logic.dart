import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mine_sweeper/src/rust/api/logic.dart';

export 'package:mine_sweeper/src/rust/api/logic.dart'
    show GameSetting, MineFieldCell, GameResult;

final gameLogic = GameLogic._new();
final startCustomGameLogic = StartCustomGameLogic._new();

final class GameLogic {
  final StateProvider<GameState> stateProvider;
  final GameLogicInner inner;

  GameLogic._({required this.stateProvider, required this.inner});

  factory GameLogic._new() {
    final state = GameState();
    final stateProvider = StateProvider((ref) => state);
    final inner = GameLogicInner();
    return GameLogic._(stateProvider: stateProvider, inner: inner);
  }

  void restartGame(WidgetRef ref, {GameSetting? setting}) {
    if (inner.restartGame(setting: setting)) {
      ref.read(stateProvider.notifier).state = inner.getState();
    }
  }

  void revealMineFieldCell(WidgetRef ref, int x, int y) {
    if (inner.revealMineFieldCell(x: x, y: y)) {
      ref.read(stateProvider.notifier).state = inner.getState();
    }
  }

  void toggleFlagOnMineFieldCell(WidgetRef ref, int x, int y) {
    if (inner.toggleFlagOnMineFieldCell(x: x, y: y)) {
      ref.read(stateProvider.notifier).state = inner.getState();
    }
  }
}

class StartCustomGameDialogState {
  final int mineFieldWidth;
  final int mineFieldHeight;
  final int minMineNum;
  final int maxMineNum;
  final int mineNum;

  StartCustomGameDialogState({
    required this.mineFieldWidth,
    required this.mineFieldHeight,
    required this.mineNum,
  }) : minMineNum = 1,
       maxMineNum = mineFieldWidth * mineFieldHeight - 1;

  StartCustomGameDialogState copyWith({
    int? mineFieldWidth,
    int? mineFieldHeight,
    int? mineNum,
  }) {
    return StartCustomGameDialogState(
      mineFieldWidth: mineFieldWidth ?? this.mineFieldWidth,
      mineFieldHeight: mineFieldHeight ?? this.mineFieldHeight,
      mineNum: mineNum ?? this.mineNum,
    );
  }
}

class StartCustomGameLogic {
  final StateProvider<StartCustomGameDialogState> stateProvider;

  StartCustomGameLogic._({required this.stateProvider});

  factory StartCustomGameLogic._new() {
    final state = StartCustomGameDialogState(
      mineFieldWidth: 5,
      mineFieldHeight: 5,
      mineNum: 10,
    );
    final stateProvider = StateProvider((ref) => state);
    return StartCustomGameLogic._(stateProvider: stateProvider);
  }

  void setWidth(WidgetRef ref, int width) {
    final oldState = ref.read(stateProvider);
    final cellNum = oldState.mineFieldWidth * oldState.mineFieldHeight;
    int? newMineNum = oldState.mineNum >= cellNum ? cellNum - 1 : null;
    ref.read(stateProvider.notifier).state = oldState.copyWith(
      mineFieldWidth: width,
      mineNum: newMineNum,
    );
  }

  void setHeight(WidgetRef ref, int height) {
    final oldState = ref.read(stateProvider);
    final cellNum = oldState.mineFieldWidth * oldState.mineFieldHeight;
    int? newMineNum = oldState.mineNum >= cellNum ? cellNum - 1 : null;
    ref.read(stateProvider.notifier).state = oldState.copyWith(
      mineFieldHeight: height,
      mineNum: newMineNum,
    );
  }

  void setMineNum(WidgetRef ref, int mineNum) {
    final oldState = ref.read(stateProvider);
    final cellNum = oldState.mineFieldWidth * oldState.mineFieldHeight;
    if (mineNum < 1) {
      mineNum = 1;
    } else if (mineNum >= cellNum) {
      mineNum = cellNum - 1;
    }
    ref.read(stateProvider.notifier).state = oldState.copyWith(
      mineNum: mineNum,
    );
  }
}
