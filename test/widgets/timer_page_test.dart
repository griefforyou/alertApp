import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_timer/models/round_config.dart';
import 'package:study_timer/models/session_state.dart';
import 'package:study_timer/models/timer_profile.dart';
import 'package:study_timer/pages/timer_page.dart';
import 'package:study_timer/services/timer_service.dart';

void main() {
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (call) async => call.method == 'init' ? true : null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async => call.method == 'create' ? 1 : null,
    );
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers.global'), null);
    messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers'), null);
  });

  testWidgets('break finished in background shows confirmation and pauses study',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: TimerPage()));
    await tester.pump();

    final pageState = tester.state(find.byType(TimerPage)) as dynamic;
    final TimerService service =
        pageState.timerServiceForTest as TimerService;

    final profile = TimerProfile(
      id: 'test',
      category: TimerCategory.custom,
      customName: 'Test',
      rounds: [const RoundConfig(workMinutes: 5, breakMinutes: 1)],
      multiCycle: true,
      totalCycles: 4,
    );
    await tester.runAsync(() => service.start(profile));
    await tester.pump();

    // 模拟锁屏挂起 6 分钟：学习 5 分钟 + 休息 1 分钟都已在后台结束。
    service.simulateBackgroundCatchUp(const Duration(minutes: 6));
    await tester.pump();

    // 应进入第 2 轮学习并暂停等待确认，而不是自动倒计时。
    expect(service.state!.currentPhase, Phase.learning);
    expect(service.state!.currentCycle, 2);
    expect(service.state!.isPaused, isTrue);
    expect(service.remaining!.inSeconds, inInclusiveRange(299, 300));

    // 界面应显示“休息结束！”确认框，等待点击“知道了”再开始。
    expect(find.textContaining('休息结束'), findsWidgets);
    expect(find.text('知道了'), findsOneWidget);

    // 点击“知道了”后才开始下一轮学习。
    await tester.tap(find.text('知道了'));
    await tester.pump();

    expect(service.state!.isPaused, isFalse);
    expect(find.text('知道了'), findsNothing);
  });
}
