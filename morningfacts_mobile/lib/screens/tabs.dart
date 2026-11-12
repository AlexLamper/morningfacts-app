import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../data/topics.dart';
import '../l10n.dart';
import '../models.dart';
import '../services/reminders.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'paywall.dart';
import 'today.dart';

/// Explore: browse topics; a topic opens a fact from it (Premium).
class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(appProvider);
    final sorted = [...topics]..sort((a, b) => (p.interest[b.id] ?? 0).compareTo(p.interest[a.id] ?? 0));
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        children: [
          Text(tr(p.lang, 'exploreTitle'), style: AppText.display),
          const SizedBox(height: 6),
          Text(tr(p.lang, 'exploreBody'), style: AppText.body.copyWith(color: AppColors.muted, fontSize: 16)),
          const SizedBox(height: 16),
          for (final tp in sorted)
            ListTile(
              contentPadding: EdgeInsets.zero,
              minTileHeight: 56,
              title: Text(
                tp.name(p.lang),
                style: const TextStyle(fontFamily: AppText.sans, fontWeight: FontWeight.w600, fontSize: 16),
              ),
              subtitle: Text(tr(p.lang, 'level', {'n': p.levels[tp.id] ?? 1}), style: AppText.small),
              trailing: Icon(p.premium ? Icons.chevron_right : Icons.lock_outline, color: AppColors.muted),
              shape: const Border(bottom: BorderSide(color: AppColors.line)),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => p.premium ? _TopicFactPage(topic: tp) : const PaywallScreen(),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _TopicFactPage extends StatelessWidget {
  final Topic topic;
  const _TopicFactPage({required this.topic});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: AppColors.white, surfaceTintColor: AppColors.white),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: FactFlow(onlyTopic: topic.id),
        ),
      ),
    );
  }
}

/// Saved facts, newest first.
class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(appProvider);
    final facts = ref.watch(factsProvider).value ?? const <Fact>[];
    final byId = {for (final f in facts) f.id: f};
    final saved = p.saved.reversed.map((id) => byId[id]).whereType<Fact>().toList();
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        children: [
          Text(tr(p.lang, 'savedTitle'), style: AppText.display),
          const SizedBox(height: 16),
          if (saved.isEmpty) Text(tr(p.lang, 'savedEmpty'), style: AppText.body.copyWith(color: AppColors.muted)),
          for (final f in saved)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TopicPill(topicById(f.topic).name(p.lang)),
                      const Spacer(),
                      IconButton(
                        tooltip: tr(p.lang, 'saved'),
                        onPressed: () => ref.read(appProvider.notifier).unsave(f.id),
                        icon: const Icon(Icons.bookmark, color: AppColors.orange),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(f.text(p.lang).title, style: AppText.title.copyWith(fontSize: 22)),
                  const SizedBox(height: 8),
                  Text(f.text(p.lang).body, style: AppText.body.copyWith(fontSize: 15)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Me: stats, topics and levels, language, reminder, Premium.
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(appProvider);
    final ctrl = ref.read(appProvider.notifier);
    String t(String k, [Map<String, Object> a = const {}]) => tr(p.lang, k, a);
    String fmt(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        children: [
          Text(t('meTitle'), style: AppText.display),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _stat(t('streak'), '${p.currentStreak(ctrl.today, ctrl.yesterday)}')),
              const SizedBox(width: 12),
              Expanded(child: _stat(t('factsLearned'), '${p.seen.length}')),
            ],
          ),
          const SizedBox(height: 16),
          if (p.premium)
            Text(t('premiumActive'), style: AppText.body.copyWith(fontWeight: FontWeight.w600))
          else
            PrimaryButton(
              label: t('getPremium'),
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PaywallScreen())),
            ),
          const SizedBox(height: 24),
          Text(t('language').toUpperCase(), style: AppText.label),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [for (final e in supportedLanguages.entries) ButtonSegment(value: e.key, label: Text(e.value))],
            selected: {p.lang},
            showSelectedIcon: false,
            onSelectionChanged: (s) => ctrl.setLanguage(s.first),
          ),
          const SizedBox(height: 24),
          Text(t('reminder').toUpperCase(), style: AppText.label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in const [6 * 60 + 30, 7 * 60 + 30, 8 * 60 + 30])
                ChoiceChip(
                  label: Text(fmt(m)),
                  labelStyle: _chipText(p.reminderMinutes == m),
                  selected: p.reminderMinutes == m,
                  onSelected: (_) async {
                    ctrl.setReminder(m);
                    await ReminderService.requestPermission();
                    await ReminderService.schedule(m, title: t('reminderTitle'), body: t('reminderBody'));
                  },
                ),
              ChoiceChip(
                label: Text(t('reminderOff')),
                labelStyle: _chipText(p.reminderMinutes == null),
                selected: p.reminderMinutes == null,
                onSelected: (_) async {
                  ctrl.setReminder(null);
                  await ReminderService.schedule(null, title: '', body: '');
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(t('topicsAndLevels').toUpperCase(), style: AppText.label),
          const SizedBox(height: 4),
          for (final tp in topics)
            Container(
              constraints: const BoxConstraints(minHeight: 48),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(tp.name(p.lang), style: AppText.body.copyWith(fontSize: 15))),
                  Text(t('level', {'n': p.levels[tp.id] ?? 1}), style: AppText.small),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 60,
                    child: LinearProgressIndicator(
                      value: ((p.interest[tp.id] ?? 0.2) / 3).clamp(0.0, 1.0),
                      color: AppColors.orange,
                      backgroundColor: AppColors.line,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: ctrl.reset,
              child: Text(t('resetApp'), style: AppText.small),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _chipText(bool selected) => TextStyle(
    fontFamily: AppText.sans,
    fontWeight: FontWeight.w600,
    color: selected ? AppColors.white : AppColors.ink,
  );

  Widget _stat(String label, String value) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(12)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppText.display.copyWith(fontSize: 30)),
        Text(label, style: AppText.small),
      ],
    ),
  );
}

/// Bottom navigation shell.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appProvider).lang;
    const pages = [TodayScreen(), ExploreScreen(), SavedScreen(), MeScreen()];
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: NavigationBar(
          backgroundColor: AppColors.white,
          surfaceTintColor: AppColors.white,
          indicatorColor: AppColors.paper,
          selectedIndex: index,
          onDestinationSelected: (i) => setState(() => index = i),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.wb_sunny_outlined),
              selectedIcon: const Icon(Icons.wb_sunny, color: AppColors.orange),
              label: tr(lang, 'tabToday'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.explore_outlined),
              selectedIcon: const Icon(Icons.explore, color: AppColors.orange),
              label: tr(lang, 'tabExplore'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.bookmark_border),
              selectedIcon: const Icon(Icons.bookmark, color: AppColors.orange),
              label: tr(lang, 'tabSaved'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person, color: AppColors.orange),
              label: tr(lang, 'tabMe'),
            ),
          ],
        ),
      ),
    );
  }
}
