import 'package:flutter_test/flutter_test.dart';
import 'package:mm_app/domain/budget.dart';

BudgetPlan plan({int living = 900000, int fixed = 0, int saving = 0, int days = 30}) => BudgetPlan(
      living: living, fixed: fixed, saving: saving,
      start: DateTime(2026, 11, 1), days: days);
final d1 = DateTime(2026, 11, 1), d2 = DateTime(2026, 11, 2), d3 = DateTime(2026, 11, 3);

void main() {
  group('기획서 예시', () {
    test('900,000원 / 30일 = 30,000원', () => expect(plan().available(d1, const {}), 30000));
    test('3,000원 남기고 이월하면 33,000원',
        () => expect(plan().available(d2, {d1: const DayUse(spent: 27000)}), 33000));
    test('5,000원 초과하면 25,000원',
        () => expect(plan().available(d2, {d1: const DayUse(spent: 35000)}), 25000));
  });
  test('발표 덱 예시 (900,000 - 300,000 - 100,000) / 20일 = 25,000원',
      () => expect(plan(fixed: 300000, saving: 100000, days: 20).available(d1, const {}), 25000));
  test('고정지출과 먼저 저축할 돈을 먼저 뺀다',
      () => expect(plan(living: 1200000, fixed: 200000, saving: 100000).available(d1, const {}), 30000));
  test('저축으로 보낸 돈은 다음 날로 넘어가지 않는다',
      () => expect(plan().available(d2, {d1: const DayUse(spent: 27000, toSaving: 3000)}), 30000));
  test('남은 돈보다 많이 저축할 수 없다',
      () => expect(plan().available(d2, {d1: const DayUse(spent: 27000, toSaving: 9000)}), 30000));
  test('이월이 있는 날 초과해도 같은 돈을 두 번 주지 않는다',
      () => expect(plan().available(d3, {d1: const DayUse(spent: 27000), d2: const DayUse(spent: 38000)}), 25000));
  test('기간 전체 배정 합계는 정확히 생활비와 같다', () {
    final p = plan(living: 1000000);
    final total = List.generate(30, (i) => p.base(DateTime(2026, 11, 1 + i))).reduce((a, b) => a + b);
    expect(total, 1000000);
  });
  test('고정지출이 생활비보다 크면 0원이고 음수가 아니다',
      () => expect(plan(living: 100, fixed: 500).available(d1, const {}), 0));
  test('크게 초과하면 음수 잔액이 다음 날로 이어진다',
      () => expect(plan().available(d2, {d1: const DayUse(spent: 100000)}), -40000));
  test('기간 밖 날짜는 0원', () {
    expect(plan().base(DateTime(2026, 10, 31)), 0);
    expect(plan().base(DateTime(2026, 12, 1)), 0);
  });
  test('다음 월급날이 없는 날짜면 그 달 마지막 날', () {
    expect(nextPayday(DateTime(2026, 2, 10), 31), DateTime(2026, 2, 28));
    expect(nextPayday(DateTime(2026, 11, 25), 25), DateTime(2026, 12, 25));
    expect(nextPayday(DateTime(2026, 12, 26), 25), DateTime(2027, 1, 25));
    expect(nextPayday(DateTime(2026, 11, 30), 31), DateTime(2026, 12, 31));
  });
  test('0일 기간은 만들 수 없다', () => expect(() => plan(days: 0), throwsArgumentError));
}
