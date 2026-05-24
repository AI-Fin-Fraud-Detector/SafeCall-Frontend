enum TranscriptSpeaker { caller, ai }

class TranscriptEntry {
  final TranscriptSpeaker speaker;
  final String text;
  final DateTime time;
  final bool isHighRisk;

  const TranscriptEntry({
    required this.speaker,
    required this.text,
    required this.time,
    this.isHighRisk = false,
  });
}
