/// A topic users can like or dislike. Names are per language.
class Topic {
  final String id;
  final Map<String, String> names;
  const Topic(this.id, this.names);

  String name(String lang) => names[lang] ?? names['en']!;
}

/// The text of one fact in one language.
class FactText {
  final String title;
  final String body;
  final String question;
  final List<String> options;
  final String explain;

  const FactText({
    required this.title,
    required this.body,
    required this.question,
    required this.options,
    required this.explain,
  });

  factory FactText.fromJson(Map<String, dynamic> j) => FactText(
    title: j['title'] as String,
    body: j['body'] as String,
    question: j['question'] as String,
    options: (j['options'] as List).cast<String>(),
    explain: j['explain'] as String,
  );
}

/// One fact card: a hook, a short explanation and a one-question check.
class Fact {
  final String id;
  final String topic;
  final int level;
  final int answer;
  final String source;
  final Map<String, FactText> texts;

  const Fact({
    required this.id,
    required this.topic,
    required this.level,
    required this.answer,
    required this.source,
    required this.texts,
  });

  FactText text(String lang) => texts[lang] ?? texts['en']!;

  factory Fact.fromJson(Map<String, dynamic> j) {
    final texts = <String, FactText>{};
    for (final lang in const ['en', 'nl', 'de', 'fr', 'es']) {
      final t = j[lang];
      if (t is Map<String, dynamic>) texts[lang] = FactText.fromJson(t);
    }
    return Fact(
      id: j['id'] as String,
      topic: j['topic'] as String,
      level: j['level'] as int,
      answer: j['answer'] as int,
      source: j['source'] as String,
      texts: texts,
    );
  }
}
