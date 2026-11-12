import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/picker.dart';
import '../models.dart';

/// Everything about the user lives on the device; no account is needed.
class Prefs {
  final String lang;
  final bool onboarded;
  final Map<String, double> interest;
  final Map<String, int> levels;
  final int dailyGoal;
  final int? reminderMinutes; // minutes after midnight, null = off
  final List<String> seen;
  final List<String> saved;
  final int streak;
  final String? lastDoneDay;
  final int doneToday;
  final int rightStreak;
  final int wrongStreak;
  final bool premium;
  final bool paywallSeen;

  const Prefs({
    this.lang = 'en',
    this.onboarded = false,
    this.interest = const {},
    this.levels = const {},
    this.dailyGoal = 1,
    this.reminderMinutes = 7 * 60 + 30,
    this.seen = const [],
    this.saved = const [],
    this.streak = 0,
    this.lastDoneDay,
    this.doneToday = 0,
    this.rightStreak = 0,
    this.wrongStreak = 0,
    this.premium = false,
    this.paywallSeen = false,
  });

  Prefs copyWith({
    String? lang,
    bool? onboarded,
    Map<String, double>? interest,
    Map<String, int>? levels,
    int? dailyGoal,
    int? Function()? reminderMinutes,
    List<String>? seen,
    List<String>? saved,
    int? streak,
    String? lastDoneDay,
    int? doneToday,
    int? rightStreak,
    int? wrongStreak,
    bool? premium,
    bool? paywallSeen,
  }) => Prefs(
    lang: lang ?? this.lang,
    onboarded: onboarded ?? this.onboarded,
    interest: interest ?? this.interest,
    levels: levels ?? this.levels,
    dailyGoal: dailyGoal ?? this.dailyGoal,
    reminderMinutes: reminderMinutes != null ? reminderMinutes() : this.reminderMinutes,
    seen: seen ?? this.seen,
    saved: saved ?? this.saved,
    streak: streak ?? this.streak,
    lastDoneDay: lastDoneDay ?? this.lastDoneDay,
    doneToday: doneToday ?? this.doneToday,
    rightStreak: rightStreak ?? this.rightStreak,
    wrongStreak: wrongStreak ?? this.wrongStreak,
    premium: premium ?? this.premium,
    paywallSeen: paywallSeen ?? this.paywallSeen,
  );

  Map<String, dynamic> toJson() => {
    'lang': lang,
    'onboarded': onboarded,
    'interest': interest,
    'levels': levels,
    'dailyGoal': dailyGoal,
    'reminderMinutes': reminderMinutes,
    'seen': seen,
    'saved': saved,
    'streak': streak,
    'lastDoneDay': lastDoneDay,
    'doneToday': doneToday,
    'rightStreak': rightStreak,
    'wrongStreak': wrongStreak,
    'premium': premium,
    'paywallSeen': paywallSeen,
  };

  factory Prefs.fromJson(Map<String, dynamic> j) => Prefs(
    lang: j['lang'] as String? ?? 'en',
    onboarded: j['onboarded'] as bool? ?? false,
    interest: (j['interest'] as Map? ?? {}).map((k, v) => MapEntry(k as String, (v as num).toDouble())),
    levels: (j['levels'] as Map? ?? {}).map((k, v) => MapEntry(k as String, (v as num).toInt())),
    dailyGoal: j['dailyGoal'] as int? ?? 1,
    reminderMinutes: j.containsKey('reminderMinutes') ? j['reminderMinutes'] as int? : 7 * 60 + 30,
    seen: (j['seen'] as List? ?? []).cast<String>(),
    saved: (j['saved'] as List? ?? []).cast<String>(),
    streak: j['streak'] as int? ?? 0,
    lastDoneDay: j['lastDoneDay'] as String?,
    doneToday: j['doneToday'] as int? ?? 0,
    rightStreak: j['rightStreak'] as int? ?? 0,
    wrongStreak: j['wrongStreak'] as int? ?? 0,
    premium: j['premium'] as bool? ?? false,
    paywallSeen: j['paywallSeen'] as bool? ?? false,
  );

  /// Facts done today, reset when the stored day is not today.
  int doneOn(String today) => lastDoneDay == today ? doneToday : 0;

  /// The streak as it stands today: it breaks once a whole day is missed.
  int currentStreak(String today, String yesterday) => (lastDoneDay == today || lastDoneDay == yesterday) ? streak : 0;
}

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Free users get one fact a day; Premium is unlimited.
const freeFactsPerDay = 1;

final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

/// Randomness for picking facts, overridable in tests and screenshots.
final randomProvider = Provider<Random>((ref) => Random());

/// The clock, overridable in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

class AppController extends Notifier<Prefs> {
  static const _key = 'morningfacts.prefs.v1';

  @override
  Prefs build() {
    final raw = ref.read(sharedPrefsProvider).getString(_key);
    if (raw == null) return const Prefs();
    try {
      return Prefs.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const Prefs();
    }
  }

  void _set(Prefs p) {
    state = p;
    ref.read(sharedPrefsProvider).setString(_key, jsonEncode(p.toJson()));
  }

  String get today => dayKey(ref.read(clockProvider)());
  String get yesterday => dayKey(ref.read(clockProvider)().subtract(const Duration(days: 1)));

  void setLanguage(String lang) => _set(state.copyWith(lang: lang));

  void finishOnboarding({
    required Set<String> picked,
    required Map<String, int> levels,
    required List<String> allTopics,
    required int dailyGoal,
    required int? reminderMinutes,
  }) {
    final interest = {for (final t in allTopics) t: picked.contains(t) ? interestPicked : interestOther};
    final lv = {for (final t in allTopics) t: levels[t] ?? 1};
    _set(
      state.copyWith(
        onboarded: true,
        interest: interest,
        levels: lv,
        dailyGoal: dailyGoal,
        reminderMinutes: () => reminderMinutes,
      ),
    );
  }

  void feedback(Fact fact, Signal s) {
    final interest = Map<String, double>.from(state.interest);
    final levels = Map<String, int>.from(state.levels);
    interest[fact.topic] = applyInterest(interest[fact.topic] ?? interestOther, s);
    levels[fact.topic] = applyLevel(levels[fact.topic] ?? 1, s);
    var saved = state.saved;
    if (s == Signal.save && !saved.contains(fact.id)) saved = [...saved, fact.id];
    _set(state.copyWith(interest: interest, levels: levels, saved: saved));
  }

  void unsave(String id) => _set(state.copyWith(saved: state.saved.where((x) => x != id).toList()));

  /// Records a finished fact: seen list, check result, level and streak.
  void completeFact(Fact fact, {required bool correct}) {
    final right = correct ? state.rightStreak + 1 : 0;
    final wrong = correct ? 0 : state.wrongStreak + 1;
    final levels = Map<String, int>.from(state.levels);
    final lvl = applyLevel(
      levels[fact.topic] ?? 1,
      correct ? Signal.correct : Signal.wrong,
      rightStreak: right,
      wrongStreak: wrong,
    );
    final changed = lvl != (levels[fact.topic] ?? 1);
    levels[fact.topic] = lvl;

    final t = today;
    final firstToday = state.lastDoneDay != t;
    final streak = !firstToday ? state.streak : (state.lastDoneDay == yesterday ? state.streak + 1 : 1);
    _set(
      state.copyWith(
        seen: state.seen.contains(fact.id) ? state.seen : [...state.seen, fact.id],
        levels: levels,
        rightStreak: changed ? 0 : right,
        wrongStreak: changed ? 0 : wrong,
        streak: streak,
        lastDoneDay: t,
        doneToday: state.doneOn(t) + 1,
      ),
    );
  }

  void setPremium(bool v) => _set(state.copyWith(premium: v));
  void markPaywallSeen() => _set(state.copyWith(paywallSeen: true));
  void setDailyGoal(int n) => _set(state.copyWith(dailyGoal: n));
  void setReminder(int? minutes) => _set(state.copyWith(reminderMinutes: () => minutes));
  void reset() => _set(Prefs(lang: state.lang));
}

final appProvider = NotifierProvider<AppController, Prefs>(AppController.new);

final factsProvider = FutureProvider<List<Fact>>((ref) async {
  final raw = await rootBundle.loadString('assets/content/facts.json');
  final j = jsonDecode(raw) as Map<String, dynamic>;
  return (j['facts'] as List).map((e) => Fact.fromJson(e as Map<String, dynamic>)).toList();
});
