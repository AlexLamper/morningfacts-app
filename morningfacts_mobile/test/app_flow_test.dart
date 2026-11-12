import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:morningfacts_mobile/main.dart';
import 'package:morningfacts_mobile/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('onboarding to first fact, check, and the paywall after it', (tester) async {
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

    // Welcome: switch to Dutch and back to English.
    await tester.tap(find.text('Nederlands'));
    await tester.pumpAndSettle();
    expect(find.text('Beginnen'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    // Topics: Continue stays disabled until 5 are picked.
    for (final name in ['Physics', 'Space', 'History', 'Psychology']) {
      await tester.tap(find.text(name));
    }
    await tester.pumpAndSettle();
    final btn = find.widgetWithText(FilledButton, 'Continue');
    expect(tester.widget<FilledButton>(btn).onPressed, isNull);
    await tester.tap(find.text('Money'));
    await tester.pumpAndSettle();
    expect(find.text('5 selected'), findsOneWidget);
    await tester.tap(btn);
    await tester.pumpAndSettle();

    // Levels, then goal.
    expect(find.text('How much do you already know?'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Your morning routine'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Home: today's fact.
    expect(find.text('Good morning'), findsOneWidget);
    expect(find.text("TODAY'S FACT"), findsOneWidget);
    await tester.tap(find.text('Like'));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('DO YOU REMEMBER?'), findsOneWidget);

    // Answer the first option, finish, and the paywall shows once.
    final options = find.descendant(of: find.byType(InkWell), matching: find.byType(Row));
    await tester.tap(options.first);
    await tester.pumpAndSettle();
    expect(find.textContaining(RegExp(r'Correct!|Not quite\.')), findsOneWidget);
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();
    expect(find.text('Start every morning a little smarter'), findsOneWidget);

    await tester.tap(find.text('Keep 1 free fact a day'));
    await tester.pumpAndSettle();
    expect(find.text("That was today's fact"), findsOneWidget);
    expect(find.text('Day 1 of your streak. See you tomorrow morning.'), findsOneWidget);
  });
}
