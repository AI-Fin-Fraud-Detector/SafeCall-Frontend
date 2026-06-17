class StatsRecord {
  final String title;
  final DateTime time;
  final String decision;
  final int? stage;

  final String riskLabel;
  final double percent;

  StatsRecord({
    required this.title,
    required this.time,
    required this.decision,
    this.stage,
    this.riskLabel = '',
    this.percent = 0.0,
  });
}
