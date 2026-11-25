DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// 서머타임과 무관하게 날짜 차이를 센다.
int daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// 하루 사용 결과. [toSaving] 은 그날 남은 돈 중 목표 저축으로 보낸 금액.
class DayUse {
  const DayUse({required this.spent, this.toSaving = 0});
  final int spent;
  final int toSaving;
}

class BudgetPlan {
  BudgetPlan({required this.living, required this.fixed, required this.saving, required DateTime start, required this.days})
      : start = dateOnly(start) {
    if (days < 1) throw ArgumentError.value(days, 'days', '1일 이상이어야 합니다');
  }
  final int living, fixed, saving, days;
  final DateTime start;

  int get pool {
    final v = living - fixed - saving;
    return v < 0 ? 0 : v;
  }

  /// 나눠떨어지지 않는 나머지는 마지막 날에 더해 합계를 [pool] 과 맞춘다.
  int base(DateTime day) {
    final i = daysBetween(start, day);
    if (i < 0 || i >= days) return 0;
    return pool ~/ days + (i == days - 1 ? pool % days : 0);
  }

  /// [day] 이전까지의 이월액. 초과했으면 음수.
  ///
  /// 기획서의 "기본액 + 기존 이월액 - 초과액" 을 그대로 쓰면, 초과액을 이월이 포함된
  /// 사용 가능액 기준으로 재기 때문에 기존 이월액이 두 번 더해진다. 실제로 남은 돈을 그대로 넘긴다.
  int carry(DateTime day, Map<DateTime, DayUse> uses) {
    final end = daysBetween(start, day);
    var c = 0;
    for (var i = 0; i < end && i < days; i++) {
      final d = DateTime(start.year, start.month, start.day + i);
      final use = uses[d] ?? const DayUse(spent: 0);
      final left = base(d) + c - use.spent;
      c = left <= 0 ? left : left - use.toSaving.clamp(0, left);
    }
    return c;
  }

  int available(DateTime day, Map<DateTime, DayUse> uses) => base(day) + carry(day, uses);
}

DateTime _payIn(int year, int month, int payday) {
  final last = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, payday > last ? last : payday);
}

/// [today] 보다 뒤에 오는 첫 수입일. 31일처럼 없는 날짜는 그 달 마지막 날.
DateTime nextPayday(DateTime today, int payday) {
  final t = _payIn(today.year, today.month, payday);
  return t.isAfter(dateOnly(today)) ? t : _payIn(today.year, today.month + 1, payday);
}
