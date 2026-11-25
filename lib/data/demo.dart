import 'package:mm_app/domain/notice_parser.dart';

import 'models.dart';
import 'store.dart';

/// 둘러보기용 예시 데이터. 실제 사람의 정보가 아니다.
Future<MemoryStore> demoStore(DateTime now) async {
  final s = MemoryStore();
  DateTime d(int back, [int h = 12, int m = 0]) => DateTime(now.year, now.month, now.day - back, h, m);
  await s.mergeUser({
    'displayName': '하늘', 'targetAmount': 5000000, 'points': 340,
    'celebrated': [10, 25], 'growth': {'completedGoals': 0},
    'profile': const Profile(age: 21, monthlyIncome: 1200000, region: '경기', experience: '처음', risk: '낮음', goalReason: '독립').toJson(),
    'plan': PlanSettings(living: 900000, saving: 100000, start: d(10), payday: null).toJson(),
  });
  Future<void> asset(String id, String n, String c, num q, num buy, num cur) =>
      s.set('assets', id, {'name': n, 'category': c, 'quantity': q, 'purchasePrice': buy, 'currentPrice': cur});
  await asset('a1', '입출금 통장', 'cash', 1, 420000, 420000);
  await asset('a2', '정기예금', 'deposit', 1, 800000, 800000);
  await asset('a3', '국내 지수 ETF', 'etf', 12, 34000, 35500);
  await asset('a4', '미국 달러', 'fx', 120, 1330, 1344.5);
  await s.set('fixed', 'f1', const FixedExpense(id: '', name: '휴대폰 요금', amount: 45000, day: 25).toJson());
  await s.set('fixed', 'f2', FixedExpense(id: '', name: '음악 구독', amount: 10900, day: d(-1).day).toJson());
  const shops = [('김밥천국', 7500), ('스타벅스', 4800), ('시내버스', 1500), ('이마트24', 3200), ('올리브영', 12900), ('맥도날드', 8400), ('메가커피', 2500), ('교보문고', 15000)];
  var n = 0;
  for (var b = 18; b >= 1; b--) {
    for (var k = 0; k < 2; k++) {
      final (shop, amt) = shops[(b * 3 + k * 5) % shops.length];
      await s.set('transactions', 'd${n++}',
          Txn(id: '', kind: TxnKind.expense, amount: amt, merchant: shop, category: categorize(shop), at: d(b, 9 + k * 8, 12), source: k == 0 ? '문자' : '카카오톡').toJson());
    }
  }
  await s.set('transactions', 'inc', Txn(id: '', kind: TxnKind.income, amount: 500000, merchant: '알바 급여', category: Category.etc, at: d(10, 10)).toJson());
  await s.set('transactions', 'sav', Txn(id: '', kind: TxnKind.saving, amount: 60000, merchant: '목표 저축', category: Category.etc, at: d(6, 22)).toJson());
  await s.set('notices', 'n1', PendingNotice(id: '', raw: '[Web발신]\n승인 12,000원', app: '문자', at: d(1, 19, 4)).toJson());
  for (var b = 14; b >= 1; b--) {
    await s.set('snapshots', 'p$b', {'at': d(b), 'total': 1640000 + (14 - b) * 11000 + (b % 3) * 6000});
  }
  return s;
}
