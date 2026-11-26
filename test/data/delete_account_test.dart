import 'package:flutter_test/flutter_test.dart';
import 'package:mm_app/data/app_model.dart';
import 'package:mm_app/data/models.dart';
import 'package:mm_app/data/store.dart';
import 'package:mm_app/models/asset.dart';

Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  test('계정 삭제는 거래, 자산, 고정지출, 알림, 기록, 프로필을 모두 지운다', () async {
    final s = MemoryStore();
    final now = DateTime(2026, 11, 1, 12);
    final m = AppModel(s, clock: () => now);
    await tick();
    await m.saveProfile(const Profile(age: 21, monthlyIncome: 1200000, region: '경기', experience: '처음', risk: '낮음'));
    await m.saveSettings(PlanSettings(living: 900000, saving: 0, start: DateTime(2026, 11, 1)));
    await m.saveAsset(Asset(id: '', name: '현금', category: 'cash', quantity: 1, purchasePrice: 0, currentPrice: 200000));
    await m.handleNotice('[KB국민카드] 4500원 승인 스타벅스 11/01 08:42', app: '문자', at: now);
    await tick();
    expect(m.txns, isNotEmpty);

    await m.deleteAccount();
    await tick();

    for (final c in Store.collections) {
      expect(await s.watch(c).first, isEmpty, reason: c);
    }
    expect(await s.watchUser().first, isEmpty);
  });

  test('둘러보기 모드에서는 계정 삭제를 하지 않는다', () async {
    final m = AppModel(MemoryStore(), demo: true);
    await tick();
    expect(m.deleteAccount, throwsStateError);
  });
}
