import 'dart:math';
import 'budget.dart';

enum PetStage {
  none('만나기 전', '금융정보를 입력하면 씨앗을 받아요'),
  seed('씨앗', '저축 1번과 7일 중 5일 기록이면 새싹이 돼요'),
  sprout('새싹', '목표 5%를 모으면 자라기 시작해요'),
  growing('성장', '목표 25%를 모으면 꽃이 피어요'),
  flower('꽃', '목표 75%를 모으면 열매가 열려요'),
  fruit('열매', '목표 100%를 달성하면 왕관을 받아요'),
  crown('왕관', '새 목표를 달성할 때마다 왕관 랭크가 올라요');

  const PetStage(this.label, this.next);
  final String label;

  /// 다음 단계 조건.
  final String next;
}

/// 왕관 랭크. 목표를 달성한 횟수만큼 오른다.
enum CrownRank {
  toy('토이 크라운'),
  bronze('브론즈 크라운'),
  platinum('플래티넘 크라운'),
  diamond('다이아 크라운'),
  ruby('루비 크라운'),
  imperial('임페리얼 크라운');

  const CrownRank(this.label);
  final String label;
}

CrownRank crownRank(int completedGoals) => CrownRank.values[(completedGoals - 1).clamp(0, CrownRank.values.length - 1)];

String petTitle(PetStage s, int completedGoals) => s == PetStage.crown ? crownRank(completedGoals).label : '${s.label} 단계';

String petNext(PetStage s, int completedGoals) {
  if (s != PetStage.crown) return s.next;
  final r = crownRank(completedGoals);
  if (r == CrownRank.imperial) return '최고 랭크, 임페리얼 크라운이에요';
  return '목표를 하나 더 달성하면 ${CrownRank.values[r.index + 1].label}이 돼요';
}

PetStage petStage({
  required bool onboarded,
  required int savings,
  required int recordDays7,
  required double percent,
  required int completedGoals,
}) {
  if (!onboarded) return PetStage.none;
  if (completedGoals > 0) return PetStage.crown;
  if (percent >= 75) return PetStage.fruit;
  if (percent >= 25) return PetStage.flower;
  if (percent >= 5) return PetStage.growing;
  if (savings >= 1 && recordDays7 >= 5) return PetStage.sprout;
  return PetStage.seed;
}

/// 5% 마다 한 칸, 최대 20칸.
int growthTicks(double percent) => (percent / 5).floor().clamp(0, 20);

int recordDays7(Set<DateTime> days, DateTime today) => [
      for (var i = 0; i < 7; i++)
        if (days.contains(DateTime(today.year, today.month, today.day - i))) 1
    ].length;

double goalPercent(int current, int goal) => goal <= 0 ? 0 : current * 100 / goal;

const milestones = [10, 25, 50, 75, 100];
List<int> newMilestones(double percent, Set<int> seen) =>
    [for (final m in milestones) if (percent >= m && !seen.contains(m)) m];

int streak(Set<DateTime> days, DateTime today) {
  DateTime back(DateTime d) => DateTime(d.year, d.month, d.day - 1);
  var d = dateOnly(today);
  if (!days.contains(d)) d = back(d);
  var n = 0;
  while (days.contains(d)) {
    n++;
    d = back(d);
  }
  return n;
}

/// 레벨 n 까지 필요한 누적 경험치 = 100 * (1 + 2 + ... + (n-1)).
int xpForLevel(int level) => 50 * level * (level - 1);
int levelOf(int xp) {
  var l = 1;
  while (xp >= xpForLevel(l + 1)) {
    l++;
  }
  return l;
}

/// 월말 적립, 월 복리. 100년 안에 못 닿으면 null.
int? monthsToGoal({required int current, required int goal, required int monthly, required double annualRate}) {
  if (current >= goal) return 0;
  final r = pow(1 + annualRate / 100, 1 / 12) - 1;
  var v = current.toDouble();
  for (var m = 1; m <= 1200; m++) {
    v = v * (1 + r) + monthly;
    if (v >= goal) return m;
  }
  return null;
}

bool isSharpDrop(int before, int after) => before > 0 && (before - after) * 10 >= before;
