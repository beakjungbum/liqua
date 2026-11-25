import 'package:flutter_test/flutter_test.dart';
import 'package:mm_app/data/models.dart';
import 'package:mm_app/domain/interview.dart';

void main() {
  const p = Profile();
  test('나이', () {
    expect(answer(p, Ask.age, '저 스물하나요 만 21세')!.age, 21);
    expect(answer(p, Ask.age, '몰라요'), isNull);
    expect(answer(p, Ask.age, '5'), isNull);
  });
  test('같은 뜻의 여러 소득 표현', () {
    for (final s in ['월 120만 원 받아요', '1,200,000원', '120 정도', '120만']) {
      expect(answer(p, Ask.income, s)!.monthlyIncome, 1200000, reason: s);
    }
    expect(answer(p, Ask.income, '없어요')!.monthlyIncome, 0);
    expect(answer(p, Ask.income, '비밀'), isNull);
  });
  test('지역은 시나 긴 이름도 안다', () {
    expect(answer(p, Ask.region, '안양 살아요')!.region, '경기');
    expect(answer(p, Ask.region, '경상남도')!.region, '경남');
    expect(answer(p, Ask.region, '화성(행성)'), isNull);
  });
  test('버튼 답은 전부 읽힌다', () {
    questions.forEach((ask, q) {
      for (final o in q.$2) {
        expect(answer(p, ask, o), isNotNull, reason: o);
      }
    });
    expect(answer(p, Ask.risk, '감수할 수 있어요')!.risk, '높음');
    expect(answer(p, Ask.risk, '조금은 괜찮아요')!.risk, '보통');
    expect(answer(p, Ask.risk, '싫어요')!.risk, '낮음');
  });
  test('앞 답을 잃지 않는다', () => expect(answer(const Profile(age: 21), Ask.region, '서울')!.age, 21));
}
