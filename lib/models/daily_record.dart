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

class DailyRecord {
  final DateTime date;
  final int totalStudySeconds;
  final int completedCycles;
  final List<SessionRecord> sessions;

  const DailyRecord({
    required this.date,
    this.totalStudySeconds = 0,
    this.completedCycles = 0,
    this.sessions = const [],
  });

  DailyRecord copyWith({
    DateTime? date,
    int? totalStudySeconds,
    int? completedCycles,
    List<SessionRecord>? sessions,
  }) {
    return DailyRecord(
      date: date ?? this.date,
      totalStudySeconds: totalStudySeconds ?? this.totalStudySeconds,
      completedCycles: completedCycles ?? this.completedCycles,
      sessions: sessions ?? this.sessions,
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String().substring(0, 10),
    'totalStudySeconds': totalStudySeconds,
    'completedCycles': completedCycles,
    'sessions': sessions.map((s) => s.toJson()).toList(),
  };

  factory DailyRecord.fromJson(Map<String, dynamic> json) => DailyRecord(
    date: DateTime.parse(json['date'] as String),
    totalStudySeconds: json['totalStudySeconds'] as int,
    completedCycles: json['completedCycles'] as int,
    sessions: (json['sessions'] as List)
        .map((s) => SessionRecord.fromJson(s as Map<String, dynamic>))
        .toList(),
  );
}
