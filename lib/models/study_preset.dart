class StudyPreset {
  final String id;
  final String name;
  final int studyMinutes;
  final int breakMinutes;
  final int totalCycles;

  const StudyPreset({
    required this.id,
    required this.name,
    required this.studyMinutes,
    required this.breakMinutes,
    required this.totalCycles,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'studyMinutes': studyMinutes,
    'breakMinutes': breakMinutes,
    'totalCycles': totalCycles,
  };

  factory StudyPreset.fromJson(Map<String, dynamic> json) => StudyPreset(
    id: json['id'] as String,
    name: json['name'] as String,
    studyMinutes: json['studyMinutes'] as int,
    breakMinutes: json['breakMinutes'] as int,
    totalCycles: json['totalCycles'] as int,
  );
}
