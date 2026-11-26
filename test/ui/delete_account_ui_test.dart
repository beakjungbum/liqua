import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_app/data/app_model.dart';
import 'package:mm_app/data/demo.dart';
import 'package:mm_app/screens/settings_screen.dart';
import 'package:mm_app/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

final at = DateTime(2026, 11, 26, 12);

Future<AppModel> pump(WidgetTester t, {required bool demo}) async {
  SharedPreferences.setMockInitialValues({});
  t.view.physicalSize = const Size(400, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final m = AppModel(await demoStore(at), clock: () => at, demo: demo);
  await t.pumpWidget(MaterialApp(home: AppScope(model: m, child: SettingsScreen(onExit: () {}))));
  await t.pump(const Duration(milliseconds: 50));
  return m;
}

void main() {
  testWidgets('로그인 계정에는 계정 삭제가 있고, 취소하면 아무것도 지우지 않는다', (t) async {
    final m = await pump(t, demo: false);
    final before = m.txns.length;
    expect(before, greaterThan(0));
    await t.tap(find.text('계정 삭제'));
    await t.pumpAndSettle();
    expect(find.text('계정을 삭제할까요?'), findsOneWidget);
    expect(find.textContaining('되돌릴 수 없어요'), findsOneWidget);
    await t.tap(find.text('취소'));
    await t.pumpAndSettle();
    expect(m.txns.length, before);
  });

  testWidgets('둘러보기에는 계정 삭제가 없다', (t) async {
    await pump(t, demo: true);
    expect(find.text('계정 삭제'), findsNothing);
  });
}
