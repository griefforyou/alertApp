import 'package:flutter_test/flutter_test.dart';

import 'package:study_timer/main.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const StudyTimerApp());
    expect(find.text('计时器'), findsWidgets);
  });
}
