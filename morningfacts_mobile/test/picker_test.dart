import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:morningfacts_mobile/data/topics.dart';
import 'package:morningfacts_mobile/logic/picker.dart';
import 'package:morningfacts_mobile/models.dart';
import 'package:morningfacts_mobile/state/app_state.dart';

Fact f(String id, String topic, int level) => Fact(
  id: id,
  topic: topic,
  level: level,
  answer: 0,
  source: 's',
  texts: const {
    'en': FactText(title: 't', body: 'b', question: 'q', options: ['a', 'b'], explain: 'e'),
  },
);

void main() {
  test('interest moves as planned and never drops below the floor', () {
    expect(applyInterest(1.0, Signal.like), closeTo(1.3, 1e-9));
    expect(applyInterest(1.0, Signal.save), closeTo(1.2, 1e-9));
    expect(applyInterest(1.0, Signal.skip), closeTo(0.9, 1e-9));
    expect(applyInterest(1.0, Signal.dislike), closeTo(0.6, 1e-9));
    expect(applyInterest(0.1, Signal.dislike), interestFloor);
  });

  test('levels go up on too easy or 3 right, down on too hard or 2 wrong', () {
    expect(applyLevel(2, Signal.tooEasy), 3);
    expect(applyLevel(2, Signal.tooHard), 1);
    expect(applyLevel(2, Signal.correct, rightStreak: 2), 2);
    expect(applyLevel(2, Signal.correct, rightStreak: 3), 3);
    expect(applyLevel(2, Signal.wrong, wrongStreak: 2), 1);
    expect(applyLevel(5, Signal.tooEasy), 5);
    expect(applyLevel(1, Signal.tooHard), 1);
  });

  test('picks an unseen fact closest to the topic level', () {
    final facts = [f('a1', 'physics', 1), f('a3', 'physics', 3), f('a5', 'physics', 5)];
    final pick = pickNext(facts: facts, interest: {'physics': 1}, levels: {'physics': 3}, seen: {}, random: Random(1));
    expect(pick!.id, 'a3');
    final next = pickNext(
      facts: facts,
      interest: {'physics': 1},
      levels: {'physics': 3},
      seen: {'a3'},
      random: Random(1),
    );
    expect(['a1', 'a5'], contains(next!.id));
  });

  test('returns null when everything is seen', () {
    expect(pickNext(facts: [f('x', 'math', 1)], interest: {}, levels: {}, seen: {'x'}), isNull);
  });

  test('liked topics come up far more often than disliked ones', () {
    final facts = [
      for (var i = 0; i < 50; i++) ...[f('p$i', 'physics', 1), f('h$i', 'history', 1)],
    ];
    final rng = Random(42);
    var physics = 0;
    for (var i = 0; i < 2000; i++) {
      final pick = pickNext(
        facts: facts,
        interest: {'physics': 2.0, 'history': 0.05},
        levels: {},
        seen: {},
        random: rng,
      )!;
      if (pick.topic == 'physics') physics++;
    }
    // Weighted share is ~97.6%, minus 10% exploration split over two topics: ~93%.
    expect(physics / 2000, greaterThan(0.88));
    expect(physics / 2000, lessThan(0.98));
  });

  test('streak breaks after a missed day', () {
    const p = Prefs(streak: 5, lastDoneDay: '2026-11-10');
    expect(p.currentStreak('2026-11-11', '2026-11-10'), 5);
    expect(p.currentStreak('2026-11-12', '2026-11-11'), 0);
  });

  test('content bundle is complete for every topic and language', () {
    final raw = File('assets/content/facts.json').readAsStringSync();
    final facts = (jsonDecode(raw)['facts'] as List).map((e) => Fact.fromJson(e as Map<String, dynamic>)).toList();
    final ids = facts.map((x) => x.id).toSet();
    expect(ids.length, facts.length, reason: 'duplicate fact ids');
    for (final tp in topics) {
      expect(facts.where((x) => x.topic == tp.id), isNotEmpty, reason: 'no facts for ${tp.id}');
    }
    for (final x in facts) {
      for (final lang in ['en', 'nl']) {
        final t = x.texts[lang];
        expect(t, isNotNull, reason: '${x.id} missing $lang');
        expect(t!.options.length, 4, reason: '${x.id} $lang options');
        expect(x.answer, inInclusiveRange(0, 3));
      }
    }
  });
}
