import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mine_sweeper/src/rust/frb_generated.dart';
import 'package:mine_sweeper/widgets.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(ProviderScope(child: const MineSweeperApp()));
}
