enum Phase { idle, learning, breaking, finished }

class SessionState {
  final DateTime startTime;
  final int studyMinutes;
  final int breakMinutes;
  final int totalCycles; // 0 = 无限
  final int currentCycle;
  final Phase currentPhase;
  final DateTime phaseStartTime;
  final bool isPaused;
  final Duration elapsedBeforePause;

  const SessionState({
    required this.startTime,
    required this.studyMinutes,
    required this.breakMinutes,
    required this.totalCycles,
    required this.currentCycle,
    required this.currentPhase,
    required this.phaseStartTime,
    this.isPaused = false,
    this.elapsedBeforePause = Duration.zero,
  });

  SessionState copyWith({
    DateTime? startTime,
    int? studyMinutes,
    int? breakMinutes,
    int? totalCycles,
    int? currentCycle,
    Phase? currentPhase,
    DateTime? phaseStartTime,
    bool? isPaused,
    Duration? elapsedBeforePause,
  }) {
    return SessionState(
      startTime: startTime ?? this.startTime,
      studyMinutes: studyMinutes ?? this.studyMinutes,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      totalCycles: totalCycles ?? this.totalCycles,
      currentCycle: currentCycle ?? this.currentCycle,
      currentPhase: currentPhase ?? this.currentPhase,
      phaseStartTime: phaseStartTime ?? this.phaseStartTime,
      isPaused: isPaused ?? this.isPaused,
      elapsedBeforePause: elapsedBeforePause ?? this.elapsedBeforePause,
    );
  }

  Map<String, dynamic> toJson() => {
    'startTime': startTime.toIso8601String(),
    'studyMinutes': studyMinutes,
    'breakMinutes': breakMinutes,
    'totalCycles': totalCycles,
    'currentCycle': currentCycle,
    'currentPhase': currentPhase.name,
    'phaseStartTime': phaseStartTime.toIso8601String(),
    'isPaused': isPaused,
    'elapsedBeforePauseMillis': elapsedBeforePause.inMilliseconds,
  };

  factory SessionState.fromJson(Map<String, dynamic> json) => SessionState(
    startTime: DateTime.parse(json['startTime'] as String),
    studyMinutes: json['studyMinutes'] as int,
    breakMinutes: json['breakMinutes'] as int,
    totalCycles: json['totalCycles'] as int,
    currentCycle: json['currentCycle'] as int,
    currentPhase: Phase.values.byName(json['currentPhase'] as String),
    phaseStartTime: DateTime.parse(json['phaseStartTime'] as String),
    isPaused: json['isPaused'] as bool? ?? false,
    elapsedBeforePause: Duration(milliseconds: json['elapsedBeforePauseMillis'] as int? ?? 0),
  );
}
