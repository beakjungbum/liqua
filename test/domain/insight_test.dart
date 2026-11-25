import 'package:flutter_test/flutter_test.dart';
import 'package:mm_app/domain/insight.dart';
import 'package:mm_app/domain/notice_parser.dart';

Spend s(int amount, Category c, int day, {int month = 11}) => Spend(amount, c, DateTime(2026, month, day));
void main() {
  final now = DateTime(2026, 11, 21);
  test('이번 달 카테고리 합계는 총합과 같고 큰 순서', () {
    final m = byCategory([s(5000, Category.cafe, 1), s(9000, Category.food, 2), s(1000, Category.cafe, 3), s(7777, Category.food, 3, month: 10)], now);
    expect(m.map((e) => e.$1), [Category.food, Category.cafe]);
    expect(m.fold(0, (a, e) => a + e.$2), 15000);
  });
  test('30건 미만이면 제안하지 않는다', () => expect(advise(List.filled(29, s(5000, Category.cafe, 2)), now, 30000), isEmpty));
  test('30건 이상이면 근거 수치가 있는 제안 3개', () {
    final list = [for (var i = 0; i < 20; i++) s(5000, Category.cafe, i % 20 + 1), for (var i = 0; i < 15; i++) s(12000, Category.food, i + 1)];
    final a = advise(list, now, 10000);
    expect(a.length, 3);
    expect(a.every((x) => RegExp(r'\d').hasMatch(x.evidence)), isTrue);
    expect(a.first.evidence, contains('280,000원'));
  });
  test('고정지출은 줄이기 제안에서 뺀다', () {
    final list = [for (var i = 0; i < 35; i++) s(100000, Category.fixed, 1), s(5000, Category.cafe, 2)];
    expect(advise(list, now, 10000).any((x) => x.title.contains('고정지출')), isFalse);
  });
}
