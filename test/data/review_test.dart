import 'package:flutter_test/flutter_test.dart';
import 'package:mm_app/data/app_model.dart';
import 'package:mm_app/data/models.dart';
import 'package:mm_app/domain/interview.dart';
import 'package:mm_app/domain/notice_parser.dart';
import 'package:mm_app/domain/rag.dart';
import 'package:mm_app/models/asset.dart';
import 'package:mm_app/services/ai_service.dart';

import 'app_model_test.dart' show make, pay, tick;
import 'app_model_test.dart' as h;

void main() {
  Future<NoticeResult> n(AppModel m, String s, {String app = '문자', DateTime? at}) => m.handleNotice(s, app: app, at: at ?? h.now);

  test('저축 기록을 지우면 저축 자산도 되돌린다', () async {
    final m = await make();
    for (var i = 0; i < 3; i++) {
      await m.sendLeftoverToSaving(30000);
      await m.deleteTxn(m.savings.single.id);
      await tick();
    }
    expect((m.total, m.todayLeft), (200000, 30000));
  });
  test('저축 기록의 금액은 고칠 수 없다', () async {
    final m = await make();
    await m.sendLeftoverToSaving(1000);
    expect(() => m.updateTxn(m.savings.single.copyWith(amount: 5)), throwsArgumentError);
  });
  test('등록한 고정지출의 결제 알림은 생활비를 두 번 줄이지 않는다', () async {
    final m = await make();
    await m.saveFixed(const FixedExpense(id: '', name: '넷플릭스', amount: 17000, day: 2));
    await tick();
    final before = m.todayLeft;
    await pay(m, 17000, shop: '넷플릭스서비스');
    expect(m.todayLeft, before);
    expect(m.txns.single.category, Category.fixed);
  });
  test('금액만 같은 다른 가게는 고정지출이 아니다', () async {
    final m = await make();
    await m.saveFixed(const FixedExpense(id: '', name: '넷플릭스', amount: 17000, day: 2));
    await tick();
    await pay(m, 17000, shop: '무신사');
    expect(m.todaySpent, 17000);
  });
  test('대화, 광고, 결제 요청은 저장하지 않는다', () async {
    final m = await make();
    for (final s in ['어제 치킨 20,000원 결제했어 나중에 줘', '등록금 3,000,000원 결제해야 해', '30,000원 결제하면 포인트 드려요', '10,000원 결제 요청이 도착했어요', '오늘만 9,900원 특가! 지금 결제하세요']) {
      expect(await n(m, s, app: '카카오톡'), NoticeResult.ignored, reason: s);
    }
    expect((m.pending.length, m.txns.length), (0, 0));
  });
  test('환불은 지출이 아니라 확인 필요', () async {
    final m = await make();
    expect(await n(m, '카카오페이\n쿠팡에서 18,900원 결제가 환불되었어요'), NoticeResult.pending);
    expect(m.txns, isEmpty);
  });
  test('두 앱에서 온 같은 취소는 한 건만 되돌린다', () async {
    final m = await make();
    await pay(m, 4500, hm: '08:00');
    await pay(m, 4500, hm: '09:00');
    const c = '[KB국민카드] 4,500원 승인취소 스타벅스 11/01 10:00';
    expect(await n(m, c), NoticeResult.cancelled);
    expect(await n(m, c, app: '카카오톡'), NoticeResult.duplicate);
    expect(m.txns.length, 1);
  });
  test('짝을 못 찾은 취소와 부분취소는 확인 필요로 남는다', () async {
    final m = await make();
    await pay(m, 50000, shop: '무신사');
    expect(await n(m, '[KB국민카드] 20,000원 부분취소 승인 무신사 11/01 10:00'), NoticeResult.pending);
    expect(await n(m, '[KB국민카드] 50,000원 승인취소 무신사 스토어 11/01 10:00'), NoticeResult.cancelled);
  });
  test('기간 마지막 날의 내일은 다음 기간이다', () async {
    final m = await make();
    await m.saveSettings(PlanSettings(living: 900000, saving: 0, start: DateTime(2026, 10, 25), payday: 25));
    h.now = DateTime(2026, 11, 24, 12);
    await tick();
    expect(m.tomorrowBudget, 30000);
  });
  test('첫 기간 금액과 매달 금액을 따로 쓴다', () {
    final s = PlanSettings(living: 900000, firstLiving: 100000, saving: 0, start: DateTime(2026, 11, 20), payday: 25);
    expect(s.planFor(DateTime(2026, 11, 20), const []).base(DateTime(2026, 11, 20)), 20000);
    expect(s.planFor(DateTime(2026, 11, 26), const []).base(DateTime(2026, 11, 26)), 30000);
    expect(PlanSettings.fromJson(s.toJson())!.firstLiving, 100000);
  });
  test('한 기간에 두 번 나가는 고정지출을 다 뺀다', () {
    final s = PlanSettings(living: 900000, saving: 0, start: DateTime(2026, 1, 31));
    expect(s.planFor(DateTime(2026, 1, 31), const [FixedExpense(id: '', name: 'n', amount: 100000, day: 1)]).fixed, 200000);
  });
  test('기간 밖 고정지출은 빼지 않는다', () {
    final s = PlanSettings(living: 900000, saving: 0, start: DateTime(2026, 11, 20), payday: 25);
    expect(s.planFor(DateTime(2026, 11, 20), const [FixedExpense(id: '', name: 'n', amount: 1, day: 28)]).fixed, 0);
  });
  test('같은 문구라도 다른 날 결제면 확인 필요에 또 남긴다', () async {
    final m = await make();
    await n(m, '승인 12,000원');
    expect(await n(m, '승인 12,000원', at: h.now.add(const Duration(days: 3))), NoticeResult.pending);
    expect(m.pending.length, 2);
  });
  test('시각 없는 알림이 다시 떠도 한 건', () async {
    final m = await make();
    const s = '토스뱅크\n4,800원 결제 | 메가커피';
    expect(await n(m, s, app: '토스'), NoticeResult.recorded);
    expect(await n(m, s, app: '토스', at: h.now.add(const Duration(seconds: 1))), NoticeResult.duplicate);
    expect(await n(m, s, app: '토스', at: h.now.add(const Duration(minutes: 30))), NoticeResult.recorded);
  });
  test('고친 저축 자산에 더해도 원래 값이 남는다', () async {
    final m = await make();
    await m.sendLeftoverToSaving(1000);
    await m.saveAsset(const Asset(id: AppModel.savingAssetId, name: '내 저축', category: 'etf', quantity: 10, purchasePrice: 9000, currentPrice: 10000));
    await m.sendLeftoverToSaving(5000);
    expect(m.total, 305000);
    expect(m.assets.firstWhere((a) => a.id == AppModel.savingAssetId).name, '내 저축');
  });
  test('급감 알림은 하루 한 번', () async {
    final m = await make();
    await m.snapshotToday();
    h.now = DateTime(2026, 11, 2, 9);
    final got = <AppAlert>[];
    m.alerts.listen(got.add);
    await m.saveAsset(Asset(id: m.assets.single.id, name: '현금', category: 'cash', quantity: 1, purchasePrice: 0, currentPrice: 100000));
    await m.snapshotToday();
    await m.snapshotToday();
    await tick();
    expect(got.length, 1);
  });
  test('이틀 전 기록과의 차이는 급감이 아니다', () async {
    final m = await make();
    await m.snapshotToday();
    h.now = DateTime(2026, 11, 3, 9);
    await m.saveAsset(Asset(id: m.assets.single.id, name: '현금', category: 'cash', quantity: 1, purchasePrice: 0, currentPrice: 100000));
    expect(m.sharpDrop, isFalse);
  });
  test('경험치는 쌓인다', () async {
    final m = await make();
    final a = m.xp;
    await pay(m, 1000);
    await pay(m, 2000, shop: '다이소');
    expect(m.xp, a + 12);
  });
  test('직접 적은 저축은 오늘 생활비를 줄이지 않는다', () async {
    final m = await make();
    await m.addTxn(TxnKind.saving, 5000, '적금', Category.etc, h.now);
    expect(m.todayLeft, 30000);
  });
  test('작은 저축 한 번이 예상 속도를 줄이지 않는다', () async {
    final m = await make();
    await m.saveSettings(PlanSettings(living: 1200000, saving: 300000, start: DateTime(2026, 11, 1)));
    await m.sendLeftoverToSaving(1000);
    expect(m.monthlySaving, 301000);
  });
  group('AI', () {
    test('권유 표현을 넓게 막는다', () {
      for (final s in ['삼성전자에 투자하세요', '지금 담으세요', '사는 게 좋아요', '매수를 추천해요', '매수하시는 것을 추천']) {
        expect(recommendsTrade(s), isTrue, reason: s);
      }
      expect(recommendsTrade('분산 투자는 위험을 나누는 방법이에요'), isFalse);
      expect(recommendsTrade('매수를 권하지 않아요'), isFalse);
    });
    test('앱이 준 적 없는 금액은 버린다', () {
      expect(AiService.parse('{"answer":"5억원을 썼어요","ids":[]}', [], mine: true, given: '이번 달 지출 12,000원'), isNull);
      expect(AiService.parse('{"answer":"12,000원을 썼어요","ids":[]}', [], mine: true, given: '이번 달 지출 12,000원'), isNotNull);
    });
    test('내 소비를 묻지 않으면 합계를 보내지 않는다', () {
      expect(AiService.asksMine('경제 공부로 돈 버는 법'), isFalse);
      expect(AiService.asksMine('국내 자산배분 펀드가 뭐야'), isFalse);
      expect(AiService.asksMine('내 자산 얼마야'), isTrue);
      expect(AiService.asksMine('이번 달 지출 어때?'), isTrue);
    });
  });
  group('인터뷰 부정 표현', () {
    const p = Profile();
    test('위험', () {
      for (final s in ['안 괜찮아요', '감수 못해요', '높은 위험은 싫어요']) {
        expect(answer(p, Ask.risk, s)!.risk, '낮음', reason: s);
      }
    });
    test('경험', () => expect(answer(p, Ask.experience, '많이 안 해봤어요')!.experience, isNot('꾸준히')));
    test('소득 단위', () {
      expect(answer(p, Ask.income, '5000원')!.monthlyIncome, 5000);
      expect(answer(p, Ask.income, '1천만원')!.monthlyIncome, 10000000);
      expect(answer(p, Ask.income, '2백만원')!.monthlyIncome, 2000000);
    });
  });
}
