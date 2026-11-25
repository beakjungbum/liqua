import 'package:flutter_test/flutter_test.dart';
import 'package:mm_app/data/app_model.dart';
import 'package:mm_app/data/models.dart';
import 'package:mm_app/domain/interview.dart';
import 'package:mm_app/domain/notice_parser.dart';
import 'package:mm_app/domain/rag.dart';
import 'package:mm_app/models/asset.dart';
import 'package:mm_app/services/ai_service.dart';

import 'app_model_test.dart' as h;

void main() {
  Future<NoticeResult> n(AppModel m, String s, String app, {DateTime? at}) => m.handleNotice(s, app: app, at: at ?? h.now);

  test('앱 이름으로 발급사를 아는 결제는 기록한다', () async {
    for (final (app, s, shop, won) in [
      ('토스', '메가커피\n4,800원 결제', '메가커피', 4800),
      ('토스', '4,800원 결제 | 메가커피', '메가커피', 4800),
      ('네이버페이', '쿠팡에서 18,900원 결제 완료', '쿠팡', 18900),
      ('KB Pay', '결제 완료\n18,900원 다이소', '다이소', 18900),
    ]) {
      final m = await h.make();
      expect(await n(m, s, app), NoticeResult.recorded, reason: s);
      expect((m.txns.single.merchant, m.txns.single.amount), (shop, won));
    }
  });
  test('광고 낱말이 섞인 진짜 승인 문자를 버리지 않는다', () async {
    for (final s in [
      '[KB국민카드] 4,500원 승인 스타벅스 11/01 08:00 이벤트 확인',
      '[Web발신]\nKB국민카드 승인\n4,500원 일시불\n11/01 08:00\n스타벅스\n앱에서 확인하세요',
      '[Web발신]\nKB국민카드 승인\n4,500원 일시불\n11/01 08:00\n스타벅스\n결제예정금액 100,000원',
      '[KB국민카드] 4,500원 승인 쿠폰나라 11/01 08:00',
    ]) {
      final m = await h.make();
      expect(await n(m, s, '문자'), NoticeResult.recorded, reason: s);
      expect(m.txns.single.amount, 4500);
    }
  });
  test('카카오톡 대화는 카드 이야기여도 저장하지 않는다', () async {
    final m = await h.make();
    for (final s in ['영희\n내 카드로 20,000원 결제했음 나중에 보내줘', '철수\n카카오페이로 치킨 20,000원 결제함 ㅋㅋ', '엄마\n치킨 20,000원 결제했어요 카드로', '총무\n회비 30,000원 승인 부탁드립니다', '영희\n국민카드 20,000원 승인 떴다 치킨집']) {
      expect(await n(m, s, '카카오톡'), NoticeResult.ignored, reason: s);
    }
    expect((m.txns.length, m.pending.length), (0, 0));
  });
  test('카카오톡의 카드사 알림은 기록한다', () async {
    final m = await h.make();
    expect(await n(m, 'KB국민카드\n[KB국민카드] 4,500원 승인 스타벅스 11/01 08:00', '카카오톡'), NoticeResult.recorded);
  });
  test('가맹점이 아닌 말은 가맹점으로 쓰지 않는다', () async {
    final m = await h.make();
    expect(await n(m, '4,800원을 결제했어요', '토스'), NoticeResult.pending);
  });
  test('같은 짝 없는 취소는 확인 필요에 한 번', () async {
    final m = await h.make();
    const c = '[KB국민카드] 9,000원 승인취소 다이소 11/01 10:00';
    await n(m, c, '문자');
    expect(await n(m, c, '문자'), NoticeResult.duplicate);
    expect(m.pending.length, 1);
    expect(m.pending.single.isRefund, isTrue);
  });
  test('취소된 승인이 다시 와도 되살아나지 않는다', () async {
    final m = await h.make();
    const a = '[KB국민카드] 4,500원 승인 스타벅스 11/01 08:00', c = '[KB국민카드] 4,500원 승인취소 스타벅스 11/01 09:00';
    await n(m, a, '문자');
    await n(m, c, '문자');
    expect(await n(m, a, '문자'), NoticeResult.duplicate);
    expect(m.todaySpent, 0);
  });
  test('같은 앱에서 2분 뒤 온 다른 취소는 따로 처리한다', () async {
    final m = await h.make();
    await n(m, '[KB국민카드] 4,500원 승인 스타벅스 11/01 08:00', '문자');
    await n(m, '[KB국민카드] 4,500원 승인 스타벅스 11/01 08:30', '문자');
    await n(m, '[KB국민카드] 4,500원 승인취소 스타벅스 11/01 10:00', '문자');
    expect(await n(m, '[KB국민카드] 4,500원 승인취소 스타벅스 11/01 10:02', '문자'), NoticeResult.cancelled);
    expect(m.todaySpent, 0);
  });
  test('열어 둔 화면에서 저장해도 취소가 풀리지 않는다', () async {
    final m = await h.make();
    await n(m, '[KB국민카드] 4,500원 승인 스타벅스 11/01 08:00', '문자');
    final old = m.txns.single;
    await n(m, '[KB국민카드] 4,500원 승인취소 스타벅스 11/01 09:00', '문자');
    await expectLater(m.updateTxn(old.copyWith(merchant: 'x')), throwsArgumentError);
    expect(m.todaySpent, 0);
  });
  test('저축을 다 빼도 단가가 음수가 되지 않는다', () async {
    final m = await h.make();
    await m.sendLeftoverToSaving(1000);
    await m.saveAsset(const Asset(id: AppModel.savingAssetId, name: 's', category: 'etf', quantity: 3, purchasePrice: 0.1, currentPrice: 0.1));
    await m.deleteTxn(m.savings.single.id);
    final a = m.assets.firstWhere((a) => a.id == AppModel.savingAssetId);
    expect((a.currentPrice, a.purchasePrice >= 0), (0, true));
  });
  test('남은 부정 표현과 큰 단위', () {
    const p = Profile();
    for (final s in ['감수하고 싶지 않아요', '높지 않게']) {
      expect(answer(p, Ask.risk, s)!.risk, '낮음', reason: s);
    }
    expect(answer(p, Ask.income, '1천5백만원'), isNull);
    expect(answer(p, Ask.income, '1억 2천만원'), isNull);
  });
  test('AI 남은 표현', () {
    expect(recommendsTrade('매수를 추천하지 않아요. 하지만 지금이 매수 적기예요'), isTrue);
    expect(AiService.numbersGiven('5천만원 썼어요', '12,000원'), isFalse);
    expect(AiService.numbersGiven('오만원 썼어요', '12,000원'), isFalse);
    for (final s in ['내가 쓴 돈 보여줘', '이번달에 쓴 돈 알려줘', '오늘은 돈 어때']) {
      expect(AiService.asksMine(s), isTrue, reason: s);
    }
    expect(AiService.asksMine('제도권 금융에서 돈 빌리는 법'), isFalse);
  });
  test('취소 낱말이 있는 알림을 알아본다', () => expect(isRefundText('부분취소'), isTrue));
}
