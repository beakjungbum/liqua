import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_app/data/app_model.dart';
import 'package:mm_app/data/demo.dart';
import 'package:mm_app/data/models.dart';
import 'package:mm_app/data/store.dart';
import 'package:mm_app/main.dart';
import 'package:mm_app/screens/book_screen.dart';
import 'package:mm_app/screens/chat_screen.dart';
import 'package:mm_app/screens/gate.dart';
import 'package:mm_app/screens/home_screen.dart';
import 'package:mm_app/screens/onboarding.dart';
import 'package:mm_app/screens/shell.dart';
import 'package:mm_app/theme/app_theme.dart';
import 'package:mm_app/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

final at = DateTime(2026, 11, 25, 14);

Future<AppModel> open(WidgetTester t, Widget Function() page, {double w = 320, double h = 640, double scale = 1, Store? store}) async {
  SharedPreferences.setMockInitialValues({});
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final s = store ?? await demoStore(at);
  final m = AppModel(s, clock: () => at, demo: true);
  await t.pumpWidget(AppScope(model: m, child: MediaQuery(
      data: MediaQueryData(size: Size(w, h), textScaler: TextScaler.linear(scale), disableAnimations: true),
      child: LiquaApp(home: MediaQuery(
          data: MediaQueryData(size: Size(w, h), textScaler: TextScaler.linear(scale), disableAnimations: true),
          child: AppScope(model: m, child: page()))))));
  await t.pump(const Duration(milliseconds: 50));
  await t.pump(const Duration(milliseconds: 50));
  return m;
}

Future<void> scrollAll(WidgetTester t) async {
  final list = find.byType(Scrollable).hitTestable();
  if (list.evaluate().isEmpty) return;
  for (var i = 0; i < 6; i++) {
    await t.drag(list.first, const Offset(0, -400), warnIfMissed: false);
    await t.pump(const Duration(milliseconds: 100));
    expect(t.takeException(), isNull);
  }
}

void main() {
  for (final (w, scale) in [(320.0, 1.0), (360.0, 1.5), (412.0, 2.0)]) {
    for (var i = 0; i < 4; i++) {
      testWidgets('탭 $i 는 ${w.toInt()}px 글씨 $scale배에서 넘치지 않는다', (t) async {
        await open(t, () => Shell(onExit: () {}, initial: i), w: w, scale: scale);
        expect(t.takeException(), isNull);
        await scrollAll(t);
      });
    }
    testWidgets('나머지 화면 ${w.toInt()}px $scale배', (t) async {
      for (final p in <Widget Function()>[
        () => const BudgetDetail(), () => const InsightScreen(), () => const FixedScreen(), () => const ChatScreen(),
        () => const InterviewScreen(), () => const PlanScreen(), () => LoginScreen(onDemo: () async {}),
      ]) {
        await open(t, p, w: w, scale: scale);
        expect(t.takeException(), isNull);
        await scrollAll(t);
      }
    });
  }

  testWidgets('처음 쓰는 사람: 인터뷰부터 홈까지', (t) async {
    final m = await open(t, () => Builder(builder: (c) => Session(model: AppScope.of(c), onExit: () {})), w: 400, h: 900, store: MemoryStore());
    await t.pump(const Duration(milliseconds: 50));
    for (final a in ['21', '120만', '안양', '처음이에요', '싫어요', '독립']) {
      await t.enterText(find.byType(TextField), a);
      await t.tap(find.byTooltip('보내기'));
      await t.pumpAndSettle();
    }
    await t.tap(find.text('맞아요'));
    await t.pumpAndSettle();
    final f = find.byType(TextFormField);
    await t.enterText(f.at(0), '900000');
    await t.enterText(f.at(1), '0');
    await t.enterText(f.at(2), '1000000');
    await t.ensureVisible(find.text('시작하기'));
    await t.tap(find.text('시작하기'));
    await t.pumpAndSettle();
    expect(m.onboarded, isTrue);
    expect(find.text('오늘 쓸 수 있는 돈'), findsWidgets);
    expect(m.todayLeft, 30000);
  });

  testWidgets('직접 기록이 홈 금액과 과소비 경고로 이어진다', (t) async {
    final m = await open(t, () => Shell(onExit: () {}, initial: 1), w: 400, h: 900);
    final before = m.todayLeft;
    await t.tap(find.text('기록'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).at(0), '${before + 5000}');
    await t.enterText(find.byType(TextFormField).at(1), '무신사');
    await t.tap(find.text('저장'));
    await t.pumpAndSettle();
    expect(m.todayLeft, -5000);
    expect(find.text('오늘 생활비를 5,000원 넘었어요'), findsOneWidget);
  });

  testWidgets('생활비 설정을 그대로 저장해도 오늘 금액이 바뀌지 않는다', (t) async {
    final m = await open(t, () => Shell(onExit: () {}), w: 400, h: 900);
    final before = (m.todayLeft, m.settings!.start);
    final c = t.element(find.byType(Shell));
    push(c, const PlanScreen());
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('저장'));
    await t.tap(find.text('저장'));
    await t.pumpAndSettle();
    expect((m.todayLeft, m.settings!.start), before);
  });

  testWidgets('다크 모드로 바뀌면 배경과 글자색이 함께 바뀐다', (t) async {
    await open(t, () => Shell(onExit: () {}), w: 400, h: 900);
    Color bg() => t.widget<Material>(find.descendant(of: find.byType(Scaffold), matching: find.byType(Material)).first).color!;
    expect(bg(), const Color(0xFFF5F8ED));
    t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
    await t.pumpAndSettle();
    expect(bg(), const Color(0xFF11180F));
    expect(t.widget<Text>(find.text('목표 달성률')).style?.color ?? AppColors.text, const Color(0xFFF5F8ED));
    expect(t.takeException(), isNull);
  });

  testWidgets('새 기간을 시작하면 첫 기간 금액이 남지 않는다', (t) async {
    final m = await open(t, () => Shell(onExit: () {}), w: 400, h: 900);
    await m.saveSettings(PlanSettings(living: 900000, firstLiving: 100000, saving: 0, start: DateTime(2026, 11, 20), payday: 25));
    push(t.element(find.byType(Shell)), const PlanScreen());
    await t.pumpAndSettle();
    await t.tap(find.byType(Switch));
    await t.enterText(find.byType(TextFormField).at(0), '900000');
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('저장'));
    await t.tap(find.text('저장'));
    await t.pumpAndSettle();
    expect(m.settings!.firstLiving, isNull);
    expect(m.plan!.living, 900000);
  });

  testWidgets('취소 알림에는 지출로 기록하는 버튼이 없다', (t) async {
    final m = await open(t, () => Shell(onExit: () {}, initial: 1), w: 400, h: 2400);
    unawaited(m.handleNotice('[KB국민카드] 9,000원 부분취소 다이소 11/25 10:00', app: '문자', at: at));
    await t.pumpAndSettle();
    expect(m.pending.length, 2);
    expect(find.text('고쳐서 기록'), findsOneWidget);
    expect(find.textContaining('취소 알림이에요'), findsOneWidget);
  });

  testWidgets('저장이 늦게 거절되면 알려 준다', (t) async {
    final m = await open(t, () => Shell(onExit: () {}), w: 400, h: 900);
    m.reportError(StateError('permission-denied'));
    await t.pumpAndSettle();
    expect(find.textContaining('저장 권한이 없어요'), findsOneWidget);
  });

  testWidgets('빈 금액은 저장되지 않고 이유를 보인다', (t) async {
    final m = await open(t, () => Shell(onExit: () {}, initial: 1), w: 400, h: 900);
    final n = m.txns.length;
    await t.tap(find.text('기록'));
    await t.pumpAndSettle();
    await t.tap(find.text('저장'));
    await t.pumpAndSettle();
    expect(find.text('금액을 숫자로 입력해 주세요'), findsOneWidget);
    expect(m.txns.length, n);
  });
}
