import 'package:flutter_test/flutter_test.dart';
import 'package:mm_app/data/app_model.dart';
import 'package:mm_app/data/models.dart';
import 'package:mm_app/data/store.dart';
import 'package:mm_app/domain/growth.dart';
import 'package:mm_app/domain/notice_parser.dart';
import 'package:mm_app/models/asset.dart';

var now = DateTime(2026, 11, 1, 12);
Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 5));

Future<AppModel> make({int target = 1000000, int cash = 200000}) async {
  now = DateTime(2026, 11, 1, 12);
  final m = AppModel(MemoryStore(), clock: () => now);
  await tick();
  await m.saveProfile(const Profile(age: 21, monthlyIncome: 1200000, region: '경기', experience: '처음', risk: '낮음'));
  await m.saveSettings(PlanSettings(living: 900000, saving: 0, start: DateTime(2026, 11, 1)));
  await m.saveAsset(Asset(id: '', name: '현금', category: 'cash', quantity: 1, purchasePrice: 0, currentPrice: cash.toDouble()));
  await m.setTarget(target);
  await tick();
  return m;
}

Future<NoticeResult> pay(AppModel m, int won, {String app = '문자', String shop = '스타벅스', String hm = '08:42'}) =>
    m.handleNotice('[KB국민카드] $won원 승인 $shop 11/01 $hm', app: app, at: now);

void main() {
  test('시연 흐름: 알림이 오면 기록되고 오늘 남은 돈이 줄어든다', () async {
    final m = await make();
    expect(m.todayLeft, 30000);
    expect(await pay(m, 4500), NoticeResult.recorded);
    expect(m.todayLeft, 25500);
    expect(m.txns.single.confirmed, isFalse);
    expect(m.txns.single.category, Category.cafe);
  });
  test('문자와 카톡으로 동시에 와도 한 건', () async {
    final m = await make();
    final r = await Future.wait([pay(m, 4500), pay(m, 4500, app: '카카오톡')]);
    expect(r, [NoticeResult.recorded, NoticeResult.duplicate]);
    expect(m.todayLeft, 25500);
  });
  test('초과하는 순간 경고가 한 번만, 내일 금액과 함께', () async {
    final m = await make();
    final got = <AppAlert>[];
    m.alerts.listen(got.add);
    await pay(m, 35000, shop: '무신사');
    await pay(m, 1000, shop: '다이소');
    await tick();
    expect(got.length, 1);
    expect(got.single.title, contains('5,000원'));
    expect(got.single.body, contains('25,000원'));
    expect(m.tomorrowBudget, 24000);
  });
  test('취소 알림은 원래 결제를 되돌린다', () async {
    final m = await make();
    await pay(m, 4500);
    expect(await m.handleNotice('[KB국민카드] 4,500원 승인취소 스타벅스 11/01 09:00', app: '문자', at: now), NoticeResult.cancelled);
    expect(m.todayLeft, 30000);
  });
  test('못 읽은 결제는 확인 필요로 남고, 고치면 기록된다', () async {
    final m = await make();
    expect(await m.handleNotice('승인 12,000원', app: '문자', at: now), NoticeResult.pending);
    expect(await m.handleNotice('승인 12,000원', app: '문자', at: now), NoticeResult.duplicate);
    expect(m.todayLeft, 30000);
    await m.resolveNotice(m.pending.single, 12000, '서점', Category.culture);
    await tick();
    expect(m.pending, isEmpty);
    expect(m.todayLeft, 18000);
  });
  test('잡담은 아무것도 남기지 않는다', () async {
    final m = await make();
    expect(await m.handleNotice('저녁 먹자', app: '카카오톡', at: now), NoticeResult.ignored);
    expect(m.pending, isEmpty);
  });
  test('남은 돈을 저축하면 자산과 달성률이 오르고 이월은 사라진다', () async {
    final m = await make();
    await pay(m, 27000);
    expect(await m.sendLeftoverToSaving(99999), 3000);
    expect(m.total, 203000);
    expect(m.todayLeft, 0);
    expect(m.tomorrowBudget, 30000);
    now = DateTime(2026, 11, 2, 9);
    expect(m.todayLeft, 30000);
  });
  test('저축을 안 하면 다음 날로 이월', () async {
    final m = await make();
    await pay(m, 27000);
    now = DateTime(2026, 11, 2, 9);
    expect(m.todayLeft, 33000);
  });
  test('축하는 단계마다 한 번, 목표를 낮춰 지나간 단계는 축하하지 않음', () async {
    final m = await make();
    final got = <AppAlert>[];
    m.alerts.listen(got.add);
    expect(m.celebrated, {10});
    await m.saveAsset(const Asset(id: '', name: '적금', category: 'deposit', quantity: 1, purchasePrice: 0, currentPrice: 60000));
    await m.saveAsset(const Asset(id: '', name: '동전', category: 'cash', quantity: 1, purchasePrice: 0, currentPrice: 100));
    await tick();
    expect(got.map((a) => a.title), ['목표의 25%를 모았어요']);
    expect(m.stage, PetStage.flower);
  });
  test('100%면 왕관이고 새 목표를 세워도 남는다', () async {
    final m = await make();
    await m.saveAsset(const Asset(id: '', name: '상금', category: 'cash', quantity: 1, purchasePrice: 0, currentPrice: 900000));
    expect(m.stage, PetStage.crown);
    await m.setTarget(50000000);
    expect(m.completedGoals, 1);
    expect(m.stage, PetStage.crown);
  });
  test('고정지출은 생활비에서 먼저 빼고 하루 지출로 다시 세지 않는다', () async {
    final m = await make();
    await m.saveFixed(const FixedExpense(id: '', name: '구독', amount: 300000, day: 15));
    await tick();
    expect(m.todayBudget, 20000);
    await m.addTxn(TxnKind.expense, 300000, '구독', Category.fixed, now);
    expect(m.todayLeft, 20000);
  });
  test('수입일이 지나면 새 기간이 시작된다', () async {
    final m = await make();
    await m.saveSettings(PlanSettings(living: 900000, saving: 0, start: DateTime(2026, 11, 1), payday: 25));
    now = DateTime(2026, 11, 25, 9);
    await tick();
    expect(m.plan!.start, DateTime(2026, 11, 25));
    expect(m.daysLeft, 30);
    expect(m.todayBudget, 30000);
  });
  test('하루 만에 10% 줄면 알린다', () async {
    final m = await make();
    await m.snapshotToday();
    now = DateTime(2026, 11, 2, 9);
    final got = <AppAlert>[];
    m.alerts.listen(got.add);
    await m.saveAsset(Asset(id: m.assets.single.id, name: '현금', category: 'cash', quantity: 1, purchasePrice: 0, currentPrice: 180000));
    await m.snapshotToday();
    await tick();
    expect(got.single.kind, AlertKind.sharpDrop);
  });
  test('0원 기록은 거절', () async {
    final m = await make();
    expect(() => m.addTxn(TxnKind.expense, 0, 'x', Category.etc, now), throwsArgumentError);
  });
  test('그래프 합계는 기록 합계와 같다', () async {
    final m = await make();
    await pay(m, 4500);
    await pay(m, 7200, shop: '다이소');
    expect(m.monthTotal, m.expenses.fold<int>(0, (a, t) => a + t.amount));
  });
}
