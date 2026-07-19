class RoundConfig {
  final int workMinutes;
  final int breakMinutes;

  const RoundConfig({this.workMinutes = 2, this.breakMinutes = 1});

  Map<String, dynamic> toJson() => {
    'workMinutes': workMinutes,
    'breakMinutes': breakMinutes,
  };

  factory RoundConfig.fromJson(Map<String, dynamic> json) => RoundConfig(
    workMinutes: json['workMinutes'] as int? ?? 2,
    breakMinutes: json['breakMinutes'] as int? ?? 1,
  );

  RoundConfig copyWith({int? workMinutes, int? breakMinutes}) => RoundConfig(
    workMinutes: workMinutes ?? this.workMinutes,
    breakMinutes: breakMinutes ?? this.breakMinutes,
  );
}
