class SessionRecord {
  final DateTime startTime;
  final DateTime endTime;
  final int completedCycles;
  final int totalStudySeconds;

  const SessionRecord({
    required this.startTime,
    required this.endTime,
    required this.completedCycles,
    required this.totalStudySeconds,
  });

  SessionRecord copyWith({
    DateTime? startTime,
    DateTime? endTime,
    int? completedCycles,
    int? totalStudySeconds,
  }) {
    return SessionRecord(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      completedCycles: completedCycles ?? this.completedCycles,
      totalStudySeconds: totalStudySeconds ?? this.totalStudySeconds,
    );
  }

  Map<String, dynamic> toJson() => {
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'completedCycles': completedCycles,
    'totalStudySeconds': totalStudySeconds,
  };

  factory SessionRecord.fromJson(Map<String, dynamic> json) => SessionRecord(
    startTime: DateTime.parse(json['startTime'] as String),
    endTime: DateTime.parse(json['endTime'] as String),
    completedCycles: json['completedCycles'] as int,
    totalStudySeconds: json['totalStudySeconds'] as int,
  );
}

class PerTypeStats {
  final int totalStudySeconds;
  final int completedCycles;

  const PerTypeStats({
    this.totalStudySeconds = 0,
    this.completedCycles = 0,
  });

  Map<String, dynamic> toJson() => {
    'totalStudySeconds': totalStudySeconds,
    'completedCycles': completedCycles,
  };

  factory PerTypeStats.fromJson(Map<String, dynamic> json) => PerTypeStats(
    totalStudySeconds: json['totalStudySeconds'] as int,
    completedCycles: json['completedCycles'] as int,
  );
}

class DailyRecord {
  final DateTime date;
  final Map<String, PerTypeStats> perTypeStats;

  const DailyRecord({
    required this.date,
    this.perTypeStats = const {},
  });

  int get totalStudySeconds =>
      perTypeStats.values.fold(0, (sum, s) => sum + s.totalStudySeconds);

  int get completedCycles =>
      perTypeStats.values.fold(0, (sum, s) => sum + s.completedCycles);

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String().substring(0, 10),
    'perTypeStats': perTypeStats.map((k, v) => MapEntry(k, v.toJson())),
  };

  factory DailyRecord.fromJson(Map<String, dynamic> json) => DailyRecord(
    date: DateTime.parse(json['date'] as String),
    perTypeStats: (json['perTypeStats'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, PerTypeStats.fromJson(v as Map<String, dynamic>)),
    ),
  );
}
