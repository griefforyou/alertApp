import 'package:flutter/material.dart';
import 'pages/timer_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StudyTimerApp());
}

class StudyTimerApp extends StatelessWidget {
  const StudyTimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '学习计时器',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2196F3),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      home: const TimerPage(),
    );
  }
}
