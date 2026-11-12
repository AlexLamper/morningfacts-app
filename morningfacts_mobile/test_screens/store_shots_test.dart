// ignore_for_file: invalid_use_of_visible_for_testing_member
// Raw app screens for the App Store listing, per device size and language.
// Run: flutter test test_screens/store_shots_test.dart --update-goldens
import 'dart:io';
import 'dart:math';

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

/// Always 0.6: no exploration, and the weighted pick lands on Physics
/// (level 2), so every listing screenshot shows the fact about ice.
class _FixedRandom implements Random {
  @override
  double nextDouble() => 0.6;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

const devices = {
  'iphone69': (Size(1320, 2868), 3.0),
  'ipad13': (Size(2064, 2752), 2.0),
};

void main() {
  setUpAll(() async {
    await _font('Inter', [for (final w in [400, 500, 600, 700]) 'assets/fonts/Inter-$w.ttf']);
    await _font('Lora', ['assets/fonts/Lora-600.ttf', 'assets/fonts/Lora-700.ttf']);
    final sdk = Platform.environment['FLUTTER_ROOT'] ?? '/home/claude/flutter-sdk';
    await _font('MaterialIcons', ['$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
  });

  for (final device in devices.entries) {
    for (final lang in ['en', 'nl']) {
      testWidgets('${device.key} $lang', (tester) async {
        tester.view.physicalSize = device.value.$1;
        tester.view.devicePixelRatio = device.value.$2;
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        await tester.pumpWidget(ProviderScope(
          overrides: [
            sharedPrefsProvider.overrideWithValue(prefs),
            clockProvider.overrideWithValue(() => DateTime(2026, 11, 12, 7, 45)),
            randomProvider.overrideWithValue(_FixedRandom()),
          ],
          child: const MorningFactsApp(),
        ));
        await tester.pumpAndSettle();
        final app = find.byType(MaterialApp);
        final dir = 'store/${device.key}/$lang';
        Future<void> shot(String name) => expectLater(app, matchesGoldenFile('$dir/$name.png'));
        String t(String en, String nl) => lang == 'en' ? en : nl;

        if (lang == 'nl') {
          await tester.tap(find.text('Nederlands'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text(t('Get started', 'Beginnen')));
        await tester.pumpAndSettle();
        for (final n in [
          t('Physics', 'Natuurkunde'),
          t('Space', 'Ruimte'),
          t('History', 'Geschiedenis'),
          t('Psychology', 'Psychologie'),
          t('Human body', 'Menselijk lichaam'),
        ]) {
          await tester.tap(find.text(n));
        }
        await tester.pumpAndSettle();
        await shot('3_topics');
        await tester.tap(find.text(t('Continue', 'Verder')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(t('Some', 'Een beetje')).first);
        await tester.tap(find.text(t('Advanced', 'Gevorderd')).at(1));
        await tester.pumpAndSettle();
        await shot('4_level');
        await tester.tap(find.text(t('Continue', 'Verder')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(t('Continue', 'Verder')));
        await tester.pumpAndSettle();
        // Fixed fact for the listing: start from the one about ice.
        await shot('1_today');
        await tester.tap(find.text(t('Next', 'Volgende')));
        await tester.pumpAndSettle();
        final options = find.descendant(of: find.byType(InkWell), matching: find.byType(Row));
        await tester.tap(options.at(1));
        await tester.pumpAndSettle();
        await shot('2_check');
        await tester.tap(find.text(t('Finish', 'Klaar')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(t('Keep 1 free fact a day', 'Houd 1 gratis feit per dag')));
        await tester.pumpAndSettle();
        await shot('5_done');
      });
    }
  }
}
