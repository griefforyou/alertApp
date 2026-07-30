import 'round_config.dart';

enum Phase { idle, learning, breaking, finished }

class SessionState {
  final DateTime startTime;
  final String? profileId;
  final List<RoundConfig> rounds;
  final int roundIndex;
  final bool multiCycle;
  final int totalCycles; // 0 = 无限
  final int currentCycle;
  final Phase currentPhase;
  final DateTime phaseStartTime;
  final bool isPaused;
  final Duration elapsedBeforePause;

  const SessionState({
    required this.startTime,
    this.profileId,
    required this.rounds,
    required this.roundIndex,
    required this.multiCycle,
    required this.totalCycles,
    required this.currentCycle,
    required this.currentPhase,
    required this.phaseStartTime,
    this.isPaused = false,
    this.elapsedBeforePause = Duration.zero,
  });

  int get studyMinutes => rounds.isNotEmpty ? rounds[roundIndex.clamp(0, rounds.length - 1)].workMinutes : 0;
  int get breakMinutes => rounds.isNotEmpty ? rounds[roundIndex.clamp(0, rounds.length - 1)].breakMinutes : 0;

  SessionState copyWith({
    DateTime? startTime,
    String? profileId,
    List<RoundConfig>? rounds,
    int? roundIndex,
    bool? multiCycle,
    int? totalCycles,
    int? currentCycle,
    Phase? currentPhase,
    DateTime? phaseStartTime,
    bool? isPaused,
    Duration? elapsedBeforePause,
  }) {
    return SessionState(
      startTime: startTime ?? this.startTime,
      profileId: profileId ?? this.profileId,
      rounds: rounds ?? this.rounds,
      roundIndex: roundIndex ?? this.roundIndex,
      multiCycle: multiCycle ?? this.multiCycle,
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
    if (profileId != null) 'profileId': profileId,
    'rounds': rounds.map((r) => r.toJson()).toList(),
    'roundIndex': roundIndex,
    'multiCycle': multiCycle,
    'totalCycles': totalCycles,
    'currentCycle': currentCycle,
    'currentPhase': currentPhase.name,
    'phaseStartTime': phaseStartTime.toIso8601String(),
    'isPaused': isPaused,
    'elapsedBeforePauseMillis': elapsedBeforePause.inMilliseconds,
  };

  factory SessionState.fromJson(Map<String, dynamic> json) {
    List<RoundConfig> rounds;
    if (json.containsKey('rounds')) {
      rounds = (json['rounds'] as List).map((e) => RoundConfig.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      rounds = [RoundConfig(
        workMinutes: json['studyMinutes'] as int? ?? 0,
        breakMinutes: json['breakMinutes'] as int? ?? 0,
      )];
    }
    return SessionState(
      startTime: DateTime.parse(json['startTime'] as String),
      profileId: json['profileId'] as String?,
      rounds: rounds,
      roundIndex: json['roundIndex'] as int? ?? 0,
      multiCycle: json['multiCycle'] as bool? ?? true,
      totalCycles: json['totalCycles'] as int,
      currentCycle: json['currentCycle'] as int,
      currentPhase: Phase.values.byName(json['currentPhase'] as String),
      phaseStartTime: DateTime.parse(json['phaseStartTime'] as String),
      isPaused: json['isPaused'] as bool? ?? false,
      elapsedBeforePause: Duration(milliseconds: json['elapsedBeforePauseMillis'] as int? ?? 0),
    );
  }
}
