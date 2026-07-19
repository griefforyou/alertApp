import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_timer/widgets/timer_display.dart';
import 'package:study_timer/models/session_state.dart';

void main() {
  group('TimerDisplay', () {
    testWidgets('shows learning phase in blue', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TimerDisplay(
            remaining: const Duration(minutes: 45),
            phase: Phase.learning,
            currentCycle: 1,
            totalCycles: 4,
            progress: 0.0,
          ),
        ),
      ));

      expect(find.text('学习中'), findsOneWidget);
      expect(find.text('45:00'), findsOneWidget);
      expect(find.text('第 1/4 轮'), findsOneWidget);
    });

    testWidgets('shows breaking phase in green', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TimerDisplay(
            remaining: const Duration(minutes: 10),
            phase: Phase.breaking,
            currentCycle: 1,
            totalCycles: 4,
            progress: 0.5,
          ),
        ),
      ));

      expect(find.text('休息中'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);
    });

    testWidgets('shows finished state', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TimerDisplay(
            remaining: Duration.zero,
            phase: Phase.finished,
            currentCycle: 4,
            totalCycles: 4,
            progress: 1.0,
          ),
        ),
      ));

      expect(find.text('已完成'), findsOneWidget);
      expect(find.text('所有轮次已完成'), findsOneWidget);
    });
  });
}
