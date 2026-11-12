import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../data/topics.dart';
import '../l10n.dart';
import '../logic/picker.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'paywall.dart';

const _months = {
  'en': [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ],
  'nl': [
    'januari',
    'februari',
    'maart',
    'april',
    'mei',
    'juni',
    'juli',
    'augustus',
    'september',
    'oktober',
    'november',
    'december',
  ],
};
const _days = {
  'en': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
  'nl': ['maandag', 'dinsdag', 'woensdag', 'donderdag', 'vrijdag', 'zaterdag', 'zondag'],
};

String formatDate(DateTime d, String lang) {
  final day = (_days[lang] ?? _days['en']!)[d.weekday - 1];
  final month = (_months[lang] ?? _months['en']!)[d.month - 1];
  return lang == 'en' ? '$day, ${d.day} $month' : '$day ${d.day} $month';
}

/// The Today tab: greeting, streak and the fact flow.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(appProvider);
    final now = ref.watch(clockProvider)();
    final ctrl = ref.read(appProvider.notifier);
    final greet = now.hour < 12 ? 'goodMorning' : (now.hour < 18 ? 'goodAfternoon' : 'goodEvening');
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(formatDate(now, p.lang), style: AppText.small),
                      const SizedBox(height: 2),
                      Text(tr(p.lang, greet), style: AppText.title),
                    ],
                  ),
                ),
                StreakBadge(p.currentStreak(ctrl.today, ctrl.yesterday)),
              ],
            ),
            const SizedBox(height: 16),
            const Expanded(child: FactFlow()),
          ],
        ),
      ),
    );
  }
}

enum _Phase { read, check, done }

/// One fact from start to finish: read it, answer the check, see the result.
/// With [onlyTopic] it picks from one topic (Explore).
class FactFlow extends ConsumerStatefulWidget {
  final String? onlyTopic;
  const FactFlow({super.key, this.onlyTopic});

  @override
  ConsumerState<FactFlow> createState() => _FactFlowState();
}

class _FactFlowState extends ConsumerState<FactFlow> {
  Fact? fact;
  _Phase phase = _Phase.read;
  int? chosen;
  final given = <Signal>{};
  bool wantsMore = false;

  void _pick(List<Fact> facts) {
    final p = ref.read(appProvider);
    fact = pickNext(
      facts: facts,
      interest: p.interest,
      levels: p.levels,
      seen: p.seen.toSet(),
      onlyTopic: widget.onlyTopic,
    );
    phase = _Phase.read;
    chosen = null;
    given.clear();
  }

  Future<void> _openPaywall() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PaywallScreen()));
  }

  void _signal(Signal s) {
    final f = fact;
    if (f == null) return;
    final opposite = {
      Signal.like: Signal.dislike,
      Signal.dislike: Signal.like,
      Signal.tooEasy: Signal.tooHard,
      Signal.tooHard: Signal.tooEasy,
    }[s];
    if (given.contains(s) || (opposite != null && given.contains(opposite))) return;
    setState(() => given.add(s));
    ref.read(appProvider.notifier).feedback(f, s);
  }

  Future<void> _finish() async {
    final f = fact!;
    final ctrl = ref.read(appProvider.notifier);
    ctrl.completeFact(f, correct: chosen == f.answer);
    setState(() => phase = _Phase.done);
    final p = ref.read(appProvider);
    if (!p.premium && !p.paywallSeen) {
      ctrl.markPaywallSeen();
      await _openPaywall();
    }
  }

  Future<void> _more(List<Fact> facts) async {
    final p = ref.read(appProvider);
    if (!p.premium) {
      await _openPaywall();
      if (!ref.read(appProvider).premium) return;
    }
    setState(() {
      wantsMore = true;
      _pick(facts);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(appProvider);
    final lang = p.lang;
    final async = ref.watch(factsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.orange)),
      error: (e, _) => Center(child: Text('$e')),
      data: (facts) {
        final ctrl = ref.read(appProvider.notifier);
        final limitReached = !p.premium && p.doneOn(ctrl.today) >= freeFactsPerDay;
        final dailyDone =
            widget.onlyTopic == null &&
            !wantsMore &&
            phase == _Phase.read &&
            fact == null &&
            (limitReached || p.doneOn(ctrl.today) >= p.dailyGoal);
        if (dailyDone || phase == _Phase.done) {
          return _done(lang, p, ctrl, facts);
        }
        if (fact == null) _pick(facts);
        final f = fact;
        if (f == null) {
          return Center(
            child: Text(tr(lang, 'allCaughtUp'), style: AppText.body, textAlign: TextAlign.center),
          );
        }
        return phase == _Phase.read ? _read(lang, p, f) : _check(lang, f);
      },
    );
  }

  Widget _read(String lang, Prefs p, Fact f) {
    final txt = f.text(lang);
    final level = p.levels[f.topic] ?? f.level;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            TopicPill(topicById(f.topic).name(lang)),
            const SizedBox(width: 8),
            Text(tr(lang, 'level', {'n': level}), style: AppText.small),
          ],
        ),
        const SizedBox(height: 12),
        const SegmentBar(filled: 1, total: 2),
        const SizedBox(height: 16),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.all(22),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr(lang, 'todaysFact'), style: AppText.label),
                    const SizedBox(height: 12),
                    Text(txt.title, style: AppText.display),
                    const SizedBox(height: 14),
                    Text(txt.body, style: AppText.body),
                    const SizedBox(height: 18),
                    Text(tr(lang, 'source', {'s': f.source}), style: AppText.small.copyWith(fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton(label: tr(lang, 'next'), onPressed: () => setState(() => phase = _Phase.check)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _fb(Icons.thumb_up_outlined, Icons.thumb_up, tr(lang, 'like'), Signal.like),
            _fb(Icons.thumb_down_outlined, Icons.thumb_down, tr(lang, 'dislike'), Signal.dislike),
            _fb(Icons.keyboard_double_arrow_up, Icons.keyboard_double_arrow_up, tr(lang, 'tooEasy'), Signal.tooEasy),
            _fb(
              Icons.keyboard_double_arrow_down,
              Icons.keyboard_double_arrow_down,
              tr(lang, 'tooHard'),
              Signal.tooHard,
            ),
            _fb(
              Icons.bookmark_border,
              Icons.bookmark,
              p.saved.contains(f.id) ? tr(lang, 'saved') : tr(lang, 'save'),
              Signal.save,
              active: p.saved.contains(f.id),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _fb(IconData icon, IconData activeIcon, String label, Signal s, {bool? active}) {
    final on = active ?? given.contains(s);
    final color = on ? AppColors.orange : AppColors.muted;
    return Expanded(
      child: Semantics(
        button: true,
        selected: on,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _signal(s),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(on ? activeIcon : icon, size: 22, color: color),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: AppText.sans, fontSize: 11, fontWeight: FontWeight.w500, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _check(String lang, Fact f) {
    final txt = f.text(lang);
    final answered = chosen != null;
    final right = chosen == f.answer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            TopicPill(topicById(f.topic).name(lang)),
            const Spacer(),
            Text(tr(lang, 'quickCheck'), style: AppText.small),
          ],
        ),
        const SizedBox(height: 12),
        const SegmentBar(filled: 2, total: 2),
        const SizedBox(height: 20),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tr(lang, 'doYouRemember'), style: AppText.label),
                const SizedBox(height: 10),
                Text(txt.question, style: AppText.display.copyWith(fontSize: 26)),
                const SizedBox(height: 18),
                for (var i = 0; i < txt.options.length; i++) ...[
                  _option(txt.options[i], i, f.answer, answered),
                  const SizedBox(height: 10),
                ],
                if (answered)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          right ? tr(lang, 'correct') : tr(lang, 'notQuite'),
                          style: TextStyle(
                            fontFamily: AppText.sans,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: right ? AppColors.correct : AppColors.wrong,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(txt.explain, style: AppText.body.copyWith(fontSize: 15)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        PrimaryButton(label: tr(lang, 'finishToday'), onPressed: answered ? _finish : null),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _option(String text, int i, int answer, bool answered) {
    final isAnswer = i == answer;
    final isChosen = chosen == i;
    Color border = AppColors.line;
    Color bg = AppColors.white;
    IconData? icon;
    Color iconColor = AppColors.correct;
    if (answered && isAnswer) {
      border = AppColors.correct;
      bg = AppColors.correctBg;
      icon = Icons.check;
    } else if (answered && isChosen) {
      border = AppColors.wrong;
      bg = AppColors.wrongBg;
      icon = Icons.close;
      iconColor = AppColors.wrong;
    }
    return Semantics(
      button: true,
      selected: isChosen,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border, width: answered && (isAnswer || isChosen) ? 2 : 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: answered ? null : () => setState(() => chosen = i),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        fontFamily: AppText.sans,
                        fontSize: 17,
                        fontWeight: answered && isAnswer ? FontWeight.w700 : FontWeight.w500,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  if (icon != null) Icon(icon, color: iconColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _done(String lang, Prefs p, AppController ctrl, List<Fact> facts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        const Center(child: SunMark(size: 120)),
        const SizedBox(height: 24),
        Text(tr(lang, 'doneTitle'), style: AppText.display, textAlign: TextAlign.center),
        const SizedBox(height: 10),
        Text(
          tr(lang, 'doneBody', {'n': p.currentStreak(ctrl.today, ctrl.yesterday)}),
          style: AppText.body.copyWith(color: AppColors.muted),
          textAlign: TextAlign.center,
        ),
        const Spacer(),
        PrimaryButton(label: tr(lang, 'oneMore'), onPressed: () => _more(facts)),
        const SizedBox(height: 20),
      ],
    );
  }
}
