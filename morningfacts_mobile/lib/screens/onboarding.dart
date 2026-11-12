import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../data/topics.dart';
import '../l10n.dart';
import '../services/reminders.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const minTopics = 5;
  static const steps = 4;
  int step = 0;
  final picked = <String>{};
  final levels = <String, int>{};
  int goal = 1;
  int? reminder = 7 * 60 + 30;

  String get lang => ref.watch(appProvider).lang;
  String t(String k, [Map<String, Object> a = const {}]) => tr(lang, k, a);

  Future<void> _finish() async {
    ref
        .read(appProvider.notifier)
        .finishOnboarding(
          picked: picked,
          levels: levels,
          allTopics: [for (final tp in topics) tp.id],
          dailyGoal: goal,
          reminderMinutes: reminder,
        );
    if (reminder != null) {
      await ReminderService.requestPermission();
      await ReminderService.schedule(reminder, title: t('reminderTitle'), body: t('reminderBody'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final canGo = switch (step) {
      1 => picked.length >= minTopics,
      _ => true,
    };
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (step > 0)
                Row(
                  children: [
                    IconButton(
                      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                      onPressed: () => setState(() => step--),
                      icon: const Icon(Icons.chevron_left, color: AppColors.ink),
                    ),
                    Expanded(
                      child: SegmentBar(filled: step + 1, total: steps),
                    ),
                    const SizedBox(width: 12),
                    Text(t('ofN', {'a': step + 1, 'b': steps}), style: AppText.small),
                  ],
                )
              else
                const SizedBox(height: 48),
              const SizedBox(height: 16),
              Expanded(
                child: switch (step) {
                  0 => _welcome(),
                  1 => _topics(),
                  2 => _levels(),
                  _ => _goal(),
                },
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: step == 0 ? t('start') : t('continue'),
                onPressed: !canGo
                    ? null
                    : () async {
                        if (step < steps - 1) {
                          setState(() => step++);
                        } else {
                          await _finish();
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _welcome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        const SunMark(size: 96),
        const SizedBox(height: 24),
        Text(t('welcomeTitle'), style: AppText.display.copyWith(fontSize: 36)),
        const SizedBox(height: 12),
        Text(t('welcomeBody'), style: AppText.body.copyWith(color: AppColors.muted)),
        const Spacer(),
        Text(t('chooseLanguage').toUpperCase(), style: AppText.label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          children: [
            for (final e in supportedLanguages.entries)
              _Choice(
                label: e.value,
                selected: lang == e.key,
                onTap: () => ref.read(appProvider.notifier).setLanguage(e.key),
              ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _topics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t('pickTopicsTitle'), style: AppText.display),
        const SizedBox(height: 8),
        Text(t('pickTopicsBody'), style: AppText.body.copyWith(fontSize: 16, color: AppColors.muted)),
        const SizedBox(height: 20),
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final tp in topics)
                  _Choice(
                    label: tp.name(lang),
                    selected: picked.contains(tp.id),
                    check: true,
                    onTap: () => setState(() => picked.contains(tp.id) ? picked.remove(tp.id) : picked.add(tp.id)),
                  ),
              ],
            ),
          ),
        ),
        Center(
          child: Text(
            t('selected', {'n': picked.length}),
            style: const TextStyle(fontFamily: AppText.sans, fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _levels() {
    final chosen = topics.where((tp) => picked.contains(tp.id)).toList();
    final names = [t('beginner'), t('some'), t('advanced')];
    const values = [1, 2, 4];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t('levelTitle'), style: AppText.display.copyWith(fontSize: 28)),
        const SizedBox(height: 8),
        Text(t('levelBody'), style: AppText.body.copyWith(fontSize: 16, color: AppColors.muted)),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: chosen.length,
            separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.line),
            itemBuilder: (_, i) {
              final tp = chosen[i];
              final current = levels[tp.id] ?? 1;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tp.name(lang),
                      style: const TextStyle(fontFamily: AppText.sans, fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          for (var j = 0; j < 3; j++)
                            Expanded(
                              child: _Segment(
                                label: names[j],
                                selected: current == values[j],
                                onTap: () => setState(() => levels[tp.id] = values[j]),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _goal() {
    const times = [6 * 60 + 30, 7 * 60 + 30, 8 * 60 + 30];
    String fmt(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t('goalTitle'), style: AppText.display),
        const SizedBox(height: 8),
        Text(t('goalBody'), style: AppText.body.copyWith(fontSize: 16, color: AppColors.muted)),
        const SizedBox(height: 24),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final n in const [1, 3, 5])
              _Choice(label: t('factsPerDay', {'n': n}), selected: goal == n, onTap: () => setState(() => goal = n)),
          ],
        ),
        const SizedBox(height: 28),
        Text(t('reminder').toUpperCase(), style: AppText.label),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final m in times)
              _Choice(label: fmt(m), selected: reminder == m, onTap: () => setState(() => reminder = m)),
            _Choice(label: t('reminderOff'), selected: reminder == null, onTap: () => setState(() => reminder = null)),
          ],
        ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  final String label;
  final bool selected;
  final bool check;
  final VoidCallback onTap;
  const _Choice({required this.label, required this.selected, required this.onTap, this.check = false});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.ink : AppColors.white,
        shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.ink : AppColors.line, width: 1.5)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (check && selected) ...[
                    const Icon(Icons.check, size: 16, color: AppColors.white),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: AppText.sans,
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? AppColors.white : AppColors.ink,
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

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Segment({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? const [BoxShadow(color: Color(0x26000000), blurRadius: 3, offset: Offset(0, 1))]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppText.sans,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.ink : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}
