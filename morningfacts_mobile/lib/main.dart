import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/onboarding.dart';
import 'screens/tabs.dart';
import 'services/purchases.dart';
import 'services/reminders.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await Future.wait([PurchaseService.init(), ReminderService.init()]);
  runApp(ProviderScope(overrides: [sharedPrefsProvider.overrideWithValue(prefs)], child: const MorningFactsApp()));
}

class MorningFactsApp extends ConsumerStatefulWidget {
  const MorningFactsApp({super.key});

  @override
  ConsumerState<MorningFactsApp> createState() => _MorningFactsAppState();
}

class _MorningFactsAppState extends ConsumerState<MorningFactsApp> {
  @override
  void initState() {
    super.initState();
    // Keep the local Premium flag in step with the store (refunds, renewals, restores).
    if (PurchaseService.available) {
      PurchaseService.isPremium().then((v) => ref.read(appProvider.notifier).setPremium(v));
    }
  }

  @override
  Widget build(BuildContext context) {
    final onboarded = ref.watch(appProvider.select((p) => p.onboarded));
    return MaterialApp(
      title: 'MorningFacts',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: onboarded ? const HomeShell() : const OnboardingScreen(),
    );
  }
}
