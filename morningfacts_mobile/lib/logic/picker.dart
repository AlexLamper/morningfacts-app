import 'dart:math';

import '../models.dart';

/// Signals from the feedback buttons and the check question.
enum Signal { like, dislike, skip, save, tooEasy, tooHard, correct, wrong }

const double interestPicked = 1.0;
const double interestOther = 0.2;
const double interestFloor = 0.05;
const double interestCeiling = 3.0;
const double explorationRate = 0.10;

/// New interest score after a signal (plan: like +0.3, save +0.2,
/// skip -0.1, dislike -0.4, never below the floor so topics can return).
double applyInterest(double current, Signal s) {
  final delta = switch (s) {
    Signal.like => 0.3,
    Signal.save => 0.2,
    Signal.skip => -0.1,
    Signal.dislike => -0.4,
    _ => 0.0,
  };
  return (current + delta).clamp(interestFloor, interestCeiling).toDouble();
}

/// New level (1-5) after a signal and the recent run of check answers.
/// Too easy or 3 right in a row: up one. Too hard or 2 wrong in a row: down one.
int applyLevel(int level, Signal s, {int rightStreak = 0, int wrongStreak = 0}) {
  var l = level;
  if (s == Signal.tooEasy || (s == Signal.correct && rightStreak >= 3)) l++;
  if (s == Signal.tooHard || (s == Signal.wrong && wrongStreak >= 2)) l--;
  return l.clamp(1, 5);
}

/// Picks the next unseen fact: a topic by weighted random on interest
/// (with some exploration so low-scored topics can come back), then the
/// unseen fact closest to the user's level for that topic.
Fact? pickNext({
  required List<Fact> facts,
  required Map<String, double> interest,
  required Map<String, int> levels,
  required Set<String> seen,
  String? onlyTopic,
  Random? random,
}) {
  final rng = random ?? Random();
  final unseen = facts.where((f) => !seen.contains(f.id) && (onlyTopic == null || f.topic == onlyTopic)).toList();
  if (unseen.isEmpty) return null;

  final byTopic = <String, List<Fact>>{};
  for (final f in unseen) {
    byTopic.putIfAbsent(f.topic, () => []).add(f);
  }
  final topicIds = byTopic.keys.toList()..sort();

  String chosen;
  if (topicIds.length == 1) {
    chosen = topicIds.first;
  } else if (rng.nextDouble() < explorationRate) {
    chosen = topicIds[rng.nextInt(topicIds.length)];
  } else {
    final weights = [for (final t in topicIds) interest[t] ?? interestOther];
    final total = weights.fold<double>(0, (a, b) => a + b);
    var r = rng.nextDouble() * total;
    chosen = topicIds.last;
    for (var i = 0; i < topicIds.length; i++) {
      r -= weights[i];
      if (r <= 0) {
        chosen = topicIds[i];
        break;
      }
    }
  }

  final level = levels[chosen] ?? 1;
  final candidates = byTopic[chosen]!
    ..sort((a, b) {
      final d = (a.level - level).abs().compareTo((b.level - level).abs());
      return d != 0 ? d : a.id.compareTo(b.id);
    });
  return candidates.first;
}
