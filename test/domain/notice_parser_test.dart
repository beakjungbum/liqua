import 'package:flutter_test/flutter_test.dart';
import 'package:mm_app/domain/notice_parser.dart';

final now = DateTime(2026, 11, 21, 12);
ParsedNotice? p(String s) => parseNotice(s, now);
void main() {
  // 형식을 흉내 낸 합성 견본. 개인 정보 없음.
  final ok = <String, (int, String, DateTime)>{
    '[KB국민카드] 4,500원 승인 스타벅스 11/21 08:42': (4500, '스타벅스', DateTime(2026, 11, 21, 8, 42)),
    '[Web발신]\nKB국민카드1234승인\n홍*동\n12,300원 일시불\n11/21 09:10\n이마트24\n누적 120,000원': (12300, '이마트24', DateTime(2026, 11, 21, 9, 10)),
    '[Web발신]\n신한카드(1234)승인 홍*동 8,900원(일시불)11/20 18:03 맥도날드 누적320,500원': (8900, '맥도날드', DateTime(2026, 11, 20, 18, 3)),
    '[Web발신]\n삼성1234승인 홍*동\n15,000원 일시불\n11/20 19:22 올리브영\n누적45,000원': (15000, '올리브영', DateTime(2026, 11, 20, 19, 22)),
    '[Web발신]\n현대카드 M 승인\n홍*동\n23,000원 일시불\n11/19 13:05\n교보문고\n누적200,000원': (23000, '교보문고', DateTime(2026, 11, 19, 13, 5)),
    '[Web발신]\n롯데카드 1*2* 승인\n홍*동\n6,700원 일시불\n11/18 21:40\nGS25\n누적 99,000원': (6700, 'GS25', DateTime(2026, 11, 18, 21, 40)),
    '[Web발신]\n하나카드(1*2*) 홍*동님 체크카드 승인 1,500원 11/21 08:10 서울버스': (1500, '서울버스', DateTime(2026, 11, 21, 8, 10)),
    '[Web발신]\n우리카드(1234)승인 홍*동님 32,000원 일시불 11/17 20:11 김밥천국': (32000, '김밥천국', DateTime(2026, 11, 17, 20, 11)),
    '토스뱅크\n4,800원 결제 | 메가커피': (4800, '메가커피', now),
    '카카오뱅크\n체크카드 승인\n7,200원 · 다이소': (7200, '다이소', now),
    '카카오페이\n결제 완료\n쿠팡에서 18,900원을 결제했어요': (18900, '쿠팡', now),
    '[Web발신]\nNH농협카드1*2*승인\n홍*동\n3,300원 일시불\n11/21 07:15\nCU 성결대점\n총누적50,000원': (3300, 'CU 성결대점', DateTime(2026, 11, 21, 7, 15)),
  };
  ok.forEach((s, e) => test(s.replaceAll('\n', ' '), () {
        final r = p(s)!;
        expect((r.amount, r.merchant, r.at), e);
        expect(r.cancelled, isFalse);
      }));
  test('누적 금액을 결제액으로 읽지 않는다', () => expect(p('누적 320,500원')?.amount, isNull));
  test('취소 알림은 취소로 표시', () {
    final r = p('[KB국민카드] 4,500원 승인취소 스타벅스 11/21 09:00')!;
    expect(r.cancelled, isTrue);
    expect(r.amount, 4500);
    expect(r.merchant, '스타벅스');
  });
  test('승인 거절은 기록하지 않는다', () => expect(p('[KB국민카드] 4,500원 승인거절 스타벅스 잔액부족'), isNull));
  test('광고는 기록하지 않는다', () => expect(p('(광고) 스타벅스 5,000원 할인 결제하고 받자'), isNull));
  test('입금은 지출이 아니다', () => expect(p('카카오뱅크 입금 50,000원 홍길동'), isNull));
  test('가맹점을 모르면 확인 필요', () => expect(p('승인 12,000원'), isNull));
  test('결제로 보이면 확인 필요 후보', () {
    expect(looksLikePayment('승인 12,000원'), isTrue);
    expect(looksLikePayment('안녕 오늘 뭐해'), isFalse);
    expect(looksLikePayment('(광고) 5,000원 결제 할인'), isFalse);
    expect(looksLikePayment('카카오뱅크 입금 50,000원'), isFalse);
  });
  test('작년 12월 알림은 작년으로', () {
    final r = parseNotice('[KB국민카드] 4,500원 승인 스타벅스 12/31 23:59', DateTime(2027, 1, 1, 0, 1))!;
    expect(r.at, DateTime(2026, 12, 31, 23, 59));
  });
  test('말이 안 되는 날짜는 받은 시각', () => expect(p('[KB국민카드] 4,500원 승인 스타벅스 13/41 25:99')?.at ?? now, now));
  test('카테고리', () {
    expect(categorize('스타벅스 안양점'), Category.cafe);
    expect(categorize('서울버스'), Category.transport);
    expect(categorize('CU 성결대점'), Category.food);
    expect(categorize('FOCUS안경'), Category.etc);
    expect(categorize('처음 보는 가게'), Category.etc);
  });
  group('중복', () {
    final a = p('[KB국민카드] 4,500원 승인 스타벅스 11/21 08:42')!;
    ParsedNotice at(int m, {int amount = 4500, String merchant = '스타벅스'}) => ParsedNotice(
        amount: amount, merchant: merchant, at: DateTime(2026, 11, 21, 8, m), cancelled: false);
    test('다른 앱에서 3분 안에 온 같은 결제', () => expect(isDuplicate(a, 'sms', at(44), 'kakao'), isTrue));
    test('같은 앱에서 분이 다르면 별개 결제', () => expect(isDuplicate(a, 'sms', at(44), 'sms'), isFalse));
    test('같은 앱 같은 분 같은 문구의 재전송', () => expect(isDuplicate(a, 'sms', at(42), 'sms'), isTrue));
    test('금액이 다르면 별개', () => expect(isDuplicate(a, 'sms', at(42, amount: 4501), 'kakao'), isFalse));
    test('지점명까지 붙어도 같은 가맹점', () => expect(isDuplicate(a, 'sms', at(42, merchant: '스타벅스 안양점'), 'kakao'), isTrue));
    test('10분 차이는 별개', () => expect(isDuplicate(a, 'sms', at(52), 'kakao'), isFalse));
  });
}
