import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mine_sweeper/logic.dart';

const int _minCustomMineFieldWidth = 4;
const int _maxCustomMineFieldWidth = 40;
const int _minCustomMineFieldHeight = 4;
const int _maxCustomMineFieldHeight = 25;
const int _maxCustomMineNum = 125;

class MineSweeperApp extends StatelessWidget {
  const MineSweeperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mine Sweeper',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightGreen),
      ),
      home: const MineSweeperHomePage(),
    );
  }
}

class MineSweeperHomePage extends ConsumerWidget {
  const MineSweeperHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(gameLogic.stateProvider.select((state) => state.gameResult), (
      _,
      gameResult,
    ) {
      _onGameResultChange(context, ref, gameResult);
    });

    return Scaffold(
      appBar: _buildAppBar(context, ref),
      body: const MineFieldWidget(),
    );
  }

  _onGameResultChange(
    BuildContext context,
    WidgetRef ref,
    GameResult gameResult,
  ) {
    String dialogTitle;
    String dialogContent;
    switch (gameResult) {
      case GameResult.playing:
        return;
      case GameResult.win:
        dialogTitle = 'Congratulations!';
        dialogContent = 'You have cleared the mine field.';
        break;
      case GameResult.lose:
        dialogTitle = 'Game Over!';
        dialogContent = 'Oops, you triggered a mine.';
        break;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(dialogTitle),
          content: Text(dialogContent),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Dismiss'),
            ),
            TextButton(
              onPressed: () {
                gameLogic.restartGame(ref);
                Navigator.of(context).pop();
              },
              child: const Text('Play Again'),
            ),
          ],
        );
      },
    );
  }

  _buildAppBar(BuildContext context, WidgetRef ref) {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      title: _buildAppBarTitle(context, ref),
      actions: [_buildAppBarMenuButton(context)],
    );
  }

  _buildAppBarTitle(BuildContext context, WidgetRef ref) {
    final gameSetting = ref.watch(
      gameLogic.stateProvider.select((state) => state.setting),
    );
    var difficultyText = '';
    gameSetting.when(
      easy: () {
        difficultyText = "Easy";
      },
      medium: () {
        difficultyText = "Medium";
      },
      hard: () {
        difficultyText = "Hard";
      },
      custom: (rows, columns, mines) {
        difficultyText = "Custom ($rows x $columns, $mines mines)";
      },
    );
    return Row(
      children: [
        const Icon(Icons.flag),
        const SizedBox(width: 8),
        Text('Mine Sweeper / $difficultyText'),
      ],
    );
  }

  _buildAppBarMenuButton(BuildContext context) {
    const pairs = [
      (0, 'Difficulty: Easy'),
      (1, 'Difficulty: Medium'),
      (2, 'Difficulty: Hard'),
      (3, 'Difficulty: Custom...'),
    ];
    return Consumer(
      builder: (context, ref, child) {
        return PopupMenuButton(
          tooltip: "Start a new game...",
          icon: const Icon(Icons.refresh),
          itemBuilder:
              (context) => [
                for (final pair in pairs)
                  PopupMenuItem(value: pair.$1, child: Text(pair.$2)),
              ],
          onSelected: (value) {
            switch (value) {
              case 0:
                gameLogic.restartGame(ref, setting: GameSetting.easy());
                break;
              case 1:
                gameLogic.restartGame(ref, setting: GameSetting.medium());
                break;
              case 2:
                gameLogic.restartGame(ref, setting: GameSetting.hard());
                break;
              case 3:
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) {
                    return StartCustomGameDialog();
                  },
                );
                break;
            }
          },
        );
      },
    );
  }
}

class StartCustomGameDialog extends ConsumerWidget {
  const StartCustomGameDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: const Text('Start a custom game...'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mine Field Width:'),
          _buildWidthSlider(context, ref),
          const Text('Mine Field Height:'),
          _buildHeightSlider(context, ref),
          const Text('Mine Number:'),
          _buildMineNumSlider(context, ref),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final state = ref.read(startCustomGameLogic.stateProvider);
            gameLogic.restartGame(
              ref,
              setting: GameSetting.custom(
                mineFieldWidth: state.mineFieldWidth,
                mineFieldHeight: state.mineFieldHeight,
                mineNum: state.mineNum,
              ),
            );
            Navigator.of(context).pop();
          },
          child: const Text('Start'),
        ),
      ],
    );
  }

  _buildWidthSlider(BuildContext context, WidgetRef ref) {
    final provider = startCustomGameLogic.stateProvider;
    final width = ref.watch(provider.select((state) => state.mineFieldWidth));
    return Row(
      children: [
        Slider(
          min: _minCustomMineFieldWidth.toDouble(),
          max: _maxCustomMineFieldWidth.toDouble(),
          value: width.toDouble(),
          divisions: _maxCustomMineFieldWidth - _minCustomMineFieldWidth,
          onChanged: (value) {
            startCustomGameLogic.setWidth(ref, value.toInt());
          },
        ),
        Text('$width'),
      ],
    );
  }

  _buildHeightSlider(BuildContext context, WidgetRef ref) {
    final provider = startCustomGameLogic.stateProvider;
    final height = ref.watch(provider.select((state) => state.mineFieldHeight));
    return Row(
      children: [
        Slider(
          min: _minCustomMineFieldHeight.toDouble(),
          max: _maxCustomMineFieldHeight.toDouble(),
          value: height.toDouble(),
          divisions: _maxCustomMineFieldHeight - _minCustomMineFieldHeight,
          onChanged: (value) {
            startCustomGameLogic.setHeight(ref, value.toInt());
          },
        ),
        Text('$height'),
      ],
    );
  }

  _buildMineNumSlider(BuildContext context, WidgetRef ref) {
    final provider = startCustomGameLogic.stateProvider;
    final state = ref.watch(
      provider.select(
        (state) => (state.minMineNum, state.maxMineNum, state.mineNum),
      ),
    );
    final minMineNum = state.$1;
    final maxMineNum = min(state.$2, _maxCustomMineNum);
    final mineNum = state.$3;
    return Row(
      children: [
        Slider(
          min: minMineNum.toDouble(),
          max: maxMineNum.toDouble(),
          value: mineNum.toDouble(),
          divisions: maxMineNum - minMineNum,
          onChanged: (value) {
            startCustomGameLogic.setMineNum(ref, value.toInt());
          },
        ),
        Text('$mineNum'),
      ],
    );
  }
}

class MineFieldWidget extends ConsumerWidget {
  const MineFieldWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorTheme = Theme.of(context).colorScheme;

    final state = ref.watch(gameLogic.stateProvider);
    final gameSetting = state.setting;
    final mineFieldWidth = gameSetting.mineFieldWidth;
    final mineFieldHeight = gameSetting.mineFieldHeight;
    final mineFieldRatio = mineFieldWidth / mineFieldHeight;
    final mineFieldCells = state.mineFieldCells;

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Center(
        child: AspectRatio(
          aspectRatio: mineFieldRatio,
          child: Container(
            color: colorTheme.primary,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Column(
                children: [
                  for (int y = 0; y < mineFieldHeight; y++)
                    Expanded(
                      child: Row(
                        children: [
                          for (int x = 0; x < mineFieldWidth; x++)
                            Expanded(
                              child: MineFieldCellWidget(
                                x,
                                y,
                                mineFieldCells[y * mineFieldWidth + x],
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MineFieldCellWidget extends ConsumerWidget {
  final int x;
  final int y;
  final MineFieldCell state;

  const MineFieldCellWidget(this.x, this.y, this.state, {super.key});

  _inner(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return state.when(
      unrevealed:
          () => GestureDetector(
            child: Container(color: colorScheme.primaryContainer),
            onTap: () {
              gameLogic.revealMineFieldCell(ref, x, y);
            },
            onSecondaryTap: () {
              gameLogic.toggleFlagOnMineFieldCell(ref, x, y);
            },
          ),
      revealed:
          (surroundingMineNum) =>
              surroundingMineNum > 0
                  ? Container(
                    color: colorScheme.secondaryContainer,
                    child: Center(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Text(
                            surroundingMineNum.toString(),
                            style: theme.textTheme.bodyMedium!.copyWith(
                              color: _surroundingMineNumTextColor(
                                surroundingMineNum,
                              ),
                              fontWeight: FontWeight.w700,
                              fontSize: constraints.maxHeight * 0.4,
                            ),
                          );
                        },
                      ),
                    ),
                  )
                  : Container(color: colorScheme.secondaryContainer),
      flagged:
          () => GestureDetector(
            child: Container(
              color: colorScheme.primaryContainer,
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Icon(
                      Icons.flag,
                      size: constraints.maxHeight * 0.4,
                      color: colorScheme.onSecondaryContainer,
                    );
                  },
                ),
              ),
            ),
            onTap: () {
              gameLogic.toggleFlagOnMineFieldCell(ref, x, y);
            },
            onSecondaryTap: () {
              gameLogic.toggleFlagOnMineFieldCell(ref, x, y);
            },
          ),
      mine:
          () => Container(
            color: colorScheme.secondaryContainer,
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Icon(
                    Icons.cancel_outlined,
                    size: constraints.maxHeight * 0.4,
                    color: Colors.red,
                  );
                },
              ),
            ),
          ),
      explodedMine:
          () => Container(
            color: colorScheme.secondaryContainer,
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Icon(
                    Icons.cancel,
                    size: constraints.maxHeight * 0.4,
                    color: Colors.red,
                  );
                },
              ),
            ),
          ),
      correctlyFlagged:
          () => Container(
            color: colorScheme.secondaryContainer,
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Icon(
                    Icons.flag,
                    size: constraints.maxHeight * 0.4,
                    color: Colors.green,
                  );
                },
              ),
            ),
          ),
      incorrectlyFlagged:
          () => Container(
            color: colorScheme.secondaryContainer,
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Icon(
                    Icons.flag,
                    size: constraints.maxHeight * 0.4,
                    color: Colors.grey,
                  );
                },
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inner = _inner(context, ref);
    return Padding(padding: const EdgeInsets.all(2), child: inner);
  }
}

Color _surroundingMineNumTextColor(int surroundingMineNum) {
  switch (surroundingMineNum) {
    case 1:
      return Colors.green;
    case 2:
      return Colors.cyan;
    case 3:
      return Colors.blue;
    case 4:
      return Colors.purple;
    case 5:
      return Colors.pink;
    case 6:
      return Colors.yellow;
    case 7:
      return Colors.orange;
    case 8:
      return Colors.red;
    default:
      return Colors.black;
  }
}
