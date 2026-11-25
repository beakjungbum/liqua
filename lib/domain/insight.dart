import 'money.dart';
import 'notice_parser.dart';

class Spend {
  const Spend(this.amount, this.category, this.at);
  final int amount;
  final Category category;
  final DateTime at;
}

class Advice {
  const Advice(this.title, this.evidence);
  final String title;

  /// 앱이 계산한 근거 수치. AI 는 이 값을 설명만 한다.
  final String evidence;
}

Iterable<Spend> _ofMonth(Iterable<Spend> all, DateTime m) =>
    all.where((s) => s.at.year == m.year && s.at.month == m.month);

/// 해당 월 카테고리 합계, 큰 순서.
List<(Category, int)> byCategory(Iterable<Spend> all, DateTime month) {
  final sum = <Category, int>{};
  for (final s in _ofMonth(all, month)) {
    sum[s.category] = (sum[s.category] ?? 0) + s.amount;
  }
  return [for (final e in sum.entries) (e.key, e.value)]..sort((a, b) => b.$2.compareTo(a.$2));
}

const adviceMinRecords = 30;

/// 기록 30건 이상일 때 개선 방향 3가지.
List<Advice> advise(Iterable<Spend> all, DateTime now, int dailyBudget) {
  if (all.length < adviceMinRecords) return const [];
  final month = _ofMonth(all, now).toList();
  final cats = byCategory(all, now);
  final total = cats.fold(0, (a, e) => a + e.$2);
  if (total == 0) return const [];
  final flexible = cats.where((e) => e.$1 != Category.fixed).toList();
  final shares = percentShares([for (final e in cats) e.$2]);
  final out = <Advice>[
    if (flexible.isNotEmpty)
      Advice('${flexible.first.$1.label} 한도를 먼저 정해 보세요',
          '이번 달 ${won(total)} 중 ${flexible.first.$1.label}이(가) ${won(flexible.first.$2)}, ${shares[cats.indexOf(flexible.first)]}%예요'),
  ];
  final byDay = <int, int>{};
  for (final s in month.where((s) => s.category != Category.fixed)) {
    byDay[s.at.day] = (byDay[s.at.day] ?? 0) + s.amount;
  }
  final over = byDay.values.where((v) => v > dailyBudget).length;
  if (dailyBudget > 0) {
    out.add(over > 0
        ? Advice('하루 기준을 넘긴 날을 줄여 보세요', '하루 ${won(dailyBudget)} 기준으로 ${byDay.length}일 중 $over일을 넘겼어요')
        : Advice('지금 흐름을 유지해 보세요', '하루 ${won(dailyBudget)} 기준을 넘긴 날이 ${byDay.length}일 중 0일이에요'));
  }
  final small = month.where((s) => s.amount <= 10000 && s.category != Category.fixed).toList();
  final smallSum = small.fold(0, (a, s) => a + s.amount);
  if (small.isNotEmpty) {
    out.add(Advice('작은 결제를 모아서 보세요', '1만 원 이하 결제가 ${small.length}번, 합계 ${won(smallSum)}이에요'));
  }
  if (out.length < 3 && byDay.isNotEmpty) {
    final avg = byDay.values.fold(0, (a, b) => a + b) ~/ byDay.length;
    out.add(Advice('쓴 날의 평균을 기준으로 삼아 보세요', '지출이 있던 ${byDay.length}일의 평균이 ${won(avg)}이에요'));
  }
  return out.take(3).toList();
}
