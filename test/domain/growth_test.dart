import 'package:flutter_test/flutter_test.dart';
import 'package:mm_app/domain/growth.dart';
import 'package:mm_app/domain/money.dart';

void main() {
  group('펫 단계 (발표 덱 9쪽)', () {
    PetStage st({bool on = true, int saves = 0, int days = 0, double pct = 0, int done = 0}) => petStage(
        onboarded: on, savings: saves, recordDays7: days, percent: pct, completedGoals: done);
    test('금융정보를 입력하기 전에는 펫이 없다', () => expect(st(on: false, pct: 80), PetStage.none));
    test('입력을 마치면 씨앗', () => expect(st(), PetStage.seed));
    test('저축 1회와 7일 중 5일 기록이 모두 있어야 새싹', () {
      expect(st(saves: 1, days: 5), PetStage.sprout);
      expect(st(saves: 1, days: 4), PetStage.seed);
      expect(st(saves: 0, days: 7), PetStage.seed);
    });
    test('진행률 경계', () {
      expect(st(pct: 4.99), PetStage.seed);
      expect(st(pct: 5), PetStage.growing);
      expect(st(pct: 24.99), PetStage.growing);
      expect(st(pct: 25), PetStage.flower);
      expect(st(pct: 74.99), PetStage.flower);
      expect(st(pct: 75), PetStage.fruit);
      expect(st(pct: 100), PetStage.fruit);
    });
    test('목표를 한 번이라도 달성하면 왕관', () => expect(st(pct: 3, done: 1), PetStage.crown));
    test('5% 단위 성장 칸', () {
      expect(growthTicks(4.9), 0);
      expect(growthTicks(5), 1);
      expect(growthTicks(24.9), 4);
      expect(growthTicks(130), 20);
    });
    test('최근 7일 기록 일수는 오늘을 포함한 7일', () {
      final t = DateTime(2026, 11, 21);
      expect(recordDays7({for (var i = 0; i < 9; i++) DateTime(2026, 11, 21 - i)}, t), 7);
      expect(recordDays7({DateTime(2026, 11, 14)}, t), 0);
      expect(recordDays7({DateTime(2026, 11, 15)}, t), 1);
    });
  });
  test('달성률: 목표 0원이면 0', () {
    expect(goalPercent(180000, 3000000), 6);
    expect(goalPercent(100, 0), 0);
  });
  test('축하는 새로 넘은 것만, 한 번에 여러 단계도', () {
    expect(newMilestones(26, {10}), [25]);
    expect(newMilestones(100, {}), [10, 25, 50, 75, 100]);
    expect(newMilestones(26, {10, 25}), isEmpty);
  });
  test('연속 기록: 오늘 기록이 없어도 어제까지 이어졌으면 유지', () {
    final t = DateTime(2026, 11, 21);
    DateTime d(int n) => DateTime(2026, 11, n);
    expect(streak({d(21), d(20), d(19)}, t), 3);
    expect(streak({d(20), d(19)}, t), 2);
    expect(streak({d(19)}, t), 0);
    expect(streak({}, t), 0);
  });
  test('경험치 레벨', () {
    expect(levelOf(0), 1);
    expect(levelOf(99), 1);
    expect(levelOf(100), 2);
    expect(levelOf(299), 2);
    expect(levelOf(300), 3);
  });
  test('복리 예측', () {
    expect(monthsToGoal(current: 0, goal: 1200000, monthly: 100000, annualRate: 0), 12);
    expect(monthsToGoal(current: 100, goal: 100, monthly: 0, annualRate: 0), 0);
    expect(monthsToGoal(current: 100, goal: 200, monthly: 0, annualRate: 0), isNull);
    expect(monthsToGoal(current: 0, goal: 2400000, monthly: 100000, annualRate: 0), 24);
    expect(monthsToGoal(current: 0, goal: 2400000, monthly: 100000, annualRate: 12), 22);
  });
  test('하루 10% 이상 줄면 급감', () {
    expect(isSharpDrop(1000000, 900000), isTrue);
    expect(isSharpDrop(1000000, 900001), isFalse);
    expect(isSharpDrop(0, 0), isFalse);
  });
  test('외화 환산: 엔은 100엔 기준', () {
    expect(toKrw(1200, Currency.usd, 1402), 1682400);
    expect(toKrw(50000, Currency.jpy, 905), 452500);
  });
  test('원화 표기', () {
    expect(won(1234567), '1,234,567원');
    expect(won(-5000), '-5,000원');
    expect(parseWon('1,200,000원'), 1200000);
    expect(parseWon('120만'), 1200000);
    expect(parseWon('1억 2,000만원'), 120000000);
    expect(parseWon('abc'), isNull);
  });
  test('비중 합계는 항상 100', () {
    final s = percentShares([1, 1, 1]);
    expect(s.reduce((a, b) => a + b), 100);
    expect(percentShares([0, 0]), [0, 0]);
  });
}
