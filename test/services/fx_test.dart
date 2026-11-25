import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mm_app/data/models.dart';
import 'package:mm_app/services/device_service.dart';
import 'package:mm_app/services/fx_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('수출입은행: 쉼표와 100엔 단위', () {
    final r = parseExim([{'cur_unit': 'USD', 'deal_bas_r': '1,402.5'}, {'cur_unit': 'JPY(100)', 'deal_bas_r': '905'}, {'cur_unit': 'X', 'deal_bas_r': ''}]);
    expect(r, {'USD': 1402.5, 'JPY': 9.05});
  });
  test('받은 뒤 끊기면 마지막 환율을 오래된 값으로 표시', () async {
    SharedPreferences.setMockInitialValues({});
    var up = true;
    final c = MockClient((_) async => up
        ? http.Response(jsonEncode({'rates': {'2026-11-20': {'USD': 0.0008}, '2026-11-19': {'USD': 0.001}}}), 200)
        : http.Response('', 500));
    final s = FxService(client: c, eximKey: '');
    final a = await s.load();
    expect(a!.rates['USD'], closeTo(1250, .01));
    expect(a.change('USD'), closeTo(25, .01));
    up = false;
    final b = await s.load();
    expect(b!.stale, isTrue);
    expect(b.rates['USD'], closeTo(1250, .01));
  });
  test('고정지출 알림은 하루 전 9시, 지났으면 다음 달', () {
    const f = FixedExpense(id: '', name: 'n', amount: 1, day: 25);
    expect(DeviceService.remindAt(f, DateTime(2026, 11, 21)), DateTime(2026, 11, 24, 9));
    expect(DeviceService.remindAt(f, DateTime(2026, 11, 24, 10)), DateTime(2026, 12, 24, 9));
    expect(DeviceService.remindAt(f, DateTime(2026, 11, 25, 8)), DateTime(2026, 12, 24, 9));
    expect(DeviceService.remindAt(const FixedExpense(id: '', name: 'n', amount: 1, day: 31), DateTime(2026, 2, 1)), DateTime(2026, 2, 27, 9));
    expect(DeviceService.remindAt(const FixedExpense(id: '', name: 'n', amount: 1, day: 1), DateTime(2026, 12, 5)), DateTime(2026, 12, 31, 9));
    expect(DeviceService.remindAt(const FixedExpense(id: '', name: 'n', amount: 1, day: 1, remind: false), DateTime(2026, 1, 1)), isNull);
  });
}
