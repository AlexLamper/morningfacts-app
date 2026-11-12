// ignore_for_file: invalid_use_of_visible_for_testing_member
// Renders every main screen to PNG with the real fonts, for design review.
// Run: flutter test test_screens --update-goldens  (images land in test_screens/shots/)
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:morningfacts_mobile/main.dart';
import 'package:morningfacts_mobile/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    await _font('Inter', [
      for (final w in [400, 500, 600, 700]) 'assets/fonts/Inter-$w.ttf',
    ]);
    await _font('Lora', ['assets/fonts/Lora-600.ttf', 'assets/fonts/Lora-700.ttf']);
    final sdk = Platform.environment['FLUTTER_ROOT'] ?? '/home/claude/flutter-sdk';
    await _font('MaterialIcons', ['$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
  });

  testWidgets('screens', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          clockProvider.overrideWithValue(() => DateTime(2026, 11, 12, 7, 45)),
        ],
        child: const MorningFactsApp(),
      ),
    );
    await tester.pumpAndSettle();
    final app = find.byType(MaterialApp);
    Future<void> shot(String name) => expectLater(app, matchesGoldenFile('shots/$name.png'));

    await shot('01_welcome');
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    for (final n in ['Physics', 'Space', 'Languages & words', 'History', 'Psychology']) {
      await tester.tap(find.text(n));
    }
    await tester.pumpAndSettle();
    await shot('02_topics');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Some').first);
    await tester.tap(find.text('Advanced').at(2));
    await tester.pumpAndSettle();
    await shot('03_level');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await shot('04_goal');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await shot('05_today');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    final options = find.descendant(of: find.byType(InkWell), matching: find.byType(Row));
    await tester.tap(options.at(1));
    await tester.pumpAndSettle();
    await shot('06_check');
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();
    await shot('07_paywall');
    await tester.tap(find.text('Keep 1 free fact a day'));
    await tester.pumpAndSettle();
    await shot('08_done');
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    await shot('09_explore');
    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    await shot('10_me');
    await tester.tap(find.text('Nederlands'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vandaag'));
    await tester.pumpAndSettle();
    await shot('11_today_nl');
  });
}
