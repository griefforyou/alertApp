class HistoryRecord {
  final String id;
  final String typeName;
  final DateTime startTime;
  final int durationSeconds;

  const HistoryRecord({
    required this.id,
    required this.typeName,
    required this.startTime,
    required this.durationSeconds,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'typeName': typeName,
        'startTime': startTime.toIso8601String(),
        'durationSeconds': durationSeconds,
      };

  factory HistoryRecord.fromJson(Map<String, dynamic> json) => HistoryRecord(
        id: json['id'] as String,
        typeName: json['typeName'] as String,
        startTime: DateTime.parse(json['startTime'] as String),
        durationSeconds: json['durationSeconds'] as int,
      );
}
