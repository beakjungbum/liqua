import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_app/data/models.dart';
import 'package:mm_app/data/store.dart';
import 'package:mm_app/domain/notice_parser.dart';
import 'package:mm_app/screens/book_screen.dart';
import 'package:mm_app/screens/gate.dart';
import 'package:mm_app/screens/onboarding.dart';
import 'package:mm_app/screens/shell.dart';
import 'package:mm_app/theme/app_theme.dart';
import 'package:mm_app/ui/widgets.dart';

import 'layout_test.dart' show at, open;

class SlowStore extends MemoryStore {
  final gate = Completer<void>();
  var armed = false;
  var refreshed = 0;
  Object? refreshError;
  @override
  Future<void> commit(List<Op> ops) async {
    await super.commit(ops);
    if (armed) await gate.future;
  }

  @override
  Future<void> refresh() async {
    refreshed++;
    if (refreshError != null) throw refreshError!;
  }
}

class NeverStore extends MemoryStore {
  @override
  Stream<Json> watchUser() => StreamController<Json>().stream;
}

/// 화면에 보이는 주황 버튼 수.
int primaries(WidgetTester t) {
  bool orange(ButtonStyleButton b, BuildContext c) {
    final s = b.style ?? const ButtonStyle();
    // ignore: invalid_use_of_protected_member
    final bg = (s.backgroundColor ?? b.themeStyleOf(c)?.backgroundColor ?? b.defaultStyleOf(c).backgroundColor)?.resolve({});
    return bg == AppColors.orange;
  }

  var n = 0;
  for (final e in find.bySubtype<ButtonStyleButton>().hitTestable().evaluate()) {
    if (orange(e.widget as ButtonStyleButton, e)) n++;
  }
  return n + find.byType(FloatingActionButton).hitTestable().evaluate().length;
}

void main() {
  for (var i = 0; i < 4; i++) {
    testWidgets('폰 레스토프: 탭 $i 에 주황 버튼은 하나뿐', (t) async {
      await open(t, () => Shell(onExit: () {}, initial: i), w: 400, h: 860);
      expect(primaries(t), 1);
    });
  }

  testWidgets('힉스: 새 기록은 자주 쓰는 분류 4개만 먼저 보이고 더 보기로 나머지가 열린다', (t) async {
    await open(t, () => Shell(onExit: () {}), w: 400, h: 900);
    await t.tap(find.byType(FloatingActionButton));
    await t.pumpAndSettle();
    Finder cat() => find.byWidgetPredicate((w) => w is ChoiceChip && Category.values.any((c) => (w.label as Text).data == c.label));
    expect(cat(), findsNWidgets(4));
    await t.tap(find.text('더 보기'));
    await t.pumpAndSettle();
    expect(cat(), findsNWidgets(Category.values.length));
  });

  testWidgets('힉스: 홈의 할 일은 한 카드에 3개까지', (t) async {
    final m = await open(t, () => Shell(onExit: () {}), w: 400, h: 900);
    for (var i = 0; i < 5; i++) {
      unawaited(m.saveFixed(FixedExpense(id: 'x$i', name: '구독$i', amount: 1000, day: at.day)));
    }
    await t.pumpAndSettle();
    expect(find.byType(TodoRow), findsNWidgets(3));
    expect(find.textContaining('더 있어요'), findsOneWidget);
  });

  testWidgets('제이콥: 기록을 밀어서 지우고 되돌릴 수 있다', (t) async {
    final m = await open(t, () => Shell(onExit: () {}, initial: 1), w: 400, h: 2000);
    final n = m.txns.length, total = m.monthTotal;
    final row = find.byType(Dismissible).first;
    await t.drag(row, const Offset(-390, 0));
    await t.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 2));
    expect(m.txns.length, n - 1);
    await t.tap(find.text('되돌리기'));
    await t.pump(const Duration(milliseconds: 100));
    expect((m.txns.length, m.monthTotal), (n, total));
  });

  testWidgets('제이콥: 저축 기록은 밀어서 지울 수 없다', (t) async {
    final m = await open(t, () => Shell(onExit: () {}, initial: 1), w: 400, h: 5000);
    final sav = m.savings.single;
    expect(find.byKey(ValueKey('swipe-${sav.id}')), findsNothing);
  });

  testWidgets('제이콥: 같은 탭을 다시 누르면 맨 위로', (t) async {
    await open(t, () => Shell(onExit: () {}), w: 400, h: 700);
    await t.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, -500));
    await t.pumpAndSettle();
    expect(find.textContaining('내 자산').hitTestable(), findsNothing);
    await t.tap(find.text('홈'));
    await t.pumpAndSettle();
    expect(find.textContaining('내 자산').hitTestable(), findsOneWidget);
  });

  testWidgets('제이콥: 달을 넘겨 볼 수 있고 다음 달로는 못 간다', (t) async {
    await open(t, () => Shell(onExit: () {}, initial: 1), w: 400, h: 900);
    expect(find.text('11월 지출'), findsOneWidget);
    expect(t.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right_rounded).first).onPressed, isNull);
    await t.tap(find.byTooltip('이전 달'));
    await t.pumpAndSettle();
    expect(find.text('10월 지출'), findsOneWidget);
  });

  for (var i = 0; i < 4; i++) {
    testWidgets('새로고침: 탭 $i 를 당기면 서버 값을 다시 읽는다', (t) async {
      final s = SlowStore()..gate.complete();
      await _seed(s);
      await open(t, () => Shell(onExit: () {}, initial: i), w: 400, h: 800, store: s);
      await t.fling(find.byType(Scrollable).hitTestable().first, const Offset(0, 400), 1200);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      await t.pump(const Duration(seconds: 2));
      expect(s.refreshed, 1);
    });
  }

  testWidgets('새로고침이 실패하면 이유를 보인다', (t) async {
    final s = SlowStore()..gate.complete();
    await _seed(s);
    s.refreshError = StateError('unavailable');
    await open(t, () => Shell(onExit: () {}), w: 400, h: 800, store: s);
    await t.fling(find.byType(Scrollable).hitTestable().first, const Offset(0, 400), 1200);
    await t.pumpAndSettle();
    expect(find.textContaining('네트워크에 연결할 수 없어요'), findsOneWidget);
  });

  testWidgets('지각된 성능: 불러오는 동안 빙글이 대신 뼈대를 보인다', (t) async {
    await open(t, () => Builder(builder: (c) => Session(model: AppScope.of(c), onExit: () {})), w: 400, h: 800, store: NeverStore());
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(Skeleton), findsWidgets);
    await t.pump(const Duration(seconds: 9));
    expect(find.text('처음 불러올 때는 인터넷 연결이 필요해요'), findsOneWidget);
  });

  testWidgets('지각된 성능: 서버가 느려도 0.4초 안에 닫히고 값이 보인다', (t) async {
    final s = SlowStore();
    await _seed(s);
    final m = await open(t, () => Shell(onExit: () {}), w: 400, h: 900, store: s);
    s.armed = true;
    await t.tap(find.byType(FloatingActionButton));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).at(0), '1000');
    await t.enterText(find.byType(TextFormField).at(1), '다이소');
    await t.tap(find.text('저장'));
    await t.pump(const Duration(milliseconds: 410));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byType(TxnForm), findsNothing);
    expect(m.todaySpent, 1000);
    s.gate.completeError(StateError('permission-denied'));
    await t.pumpAndSettle();
    expect(find.textContaining('저장 권한이 없어요'), findsOneWidget);
  });

  testWidgets('제이가르닉: 인터뷰에 몇 번째인지 보인다', (t) async {
    await open(t, () => const InterviewScreen(), w: 400, h: 900);
    expect(find.text('1 / 6'), findsOneWidget);
  });

  for (var i = 0; i < 4; i++) {
    testWidgets('피츠: 탭 $i 의 누르는 곳은 48dp 이상', (t) async {
      final h = t.ensureSemantics();
      await open(t, () => Shell(onExit: () {}, initial: i), w: 400, h: 860);
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      h.dispose();
    });
  }

  testWidgets('그리드: 넓은 화면에서 내용 폭은 600 을 넘지 않는다', (t) async {
    await open(t, () => Shell(onExit: () {}), w: 1200, h: 900);
    expect(t.getSize(find.byType(Shell)).width, 600);
  });
}

Future<void> _seed(MemoryStore s) async {
  unawaited(s.mergeUser({
    'targetAmount': 1000000,
    'profile': const Profile(age: 21, monthlyIncome: 1, region: '경기', experience: '처음', risk: '낮음').toJson(),
    'plan': PlanSettings(living: 900000, saving: 0, start: DateTime(2026, 11, 1)).toJson(),
  }));
}
