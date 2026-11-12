import '../models.dart';

/// The v1 topics. Every topic here has facts in assets/content/facts.json.
const topics = <Topic>[
  Topic('physics', {'en': 'Physics', 'nl': 'Natuurkunde'}),
  Topic('chemistry', {'en': 'Chemistry', 'nl': 'Scheikunde'}),
  Topic('math', {'en': 'Math', 'nl': 'Wiskunde'}),
  Topic('biology', {'en': 'Biology', 'nl': 'Biologie'}),
  Topic('space', {'en': 'Space', 'nl': 'Ruimte'}),
  Topic('language', {'en': 'Languages & words', 'nl': 'Taal & woorden'}),
  Topic('history', {'en': 'History', 'nl': 'Geschiedenis'}),
  Topic('geography', {'en': 'Geography', 'nl': 'Aardrijkskunde'}),
  Topic('psychology', {'en': 'Psychology', 'nl': 'Psychologie'}),
  Topic('money', {'en': 'Money', 'nl': 'Geld'}),
  Topic('tech', {'en': 'Tech', 'nl': 'Techniek'}),
  Topic('body', {'en': 'Human body', 'nl': 'Menselijk lichaam'}),
];

Topic topicById(String id) => topics.firstWhere((t) => t.id == id, orElse: () => topics.first);
