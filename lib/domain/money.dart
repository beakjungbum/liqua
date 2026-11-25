import 'package:intl/intl.dart';

enum Currency {
  usd('USD', '미국 달러', 1),
  jpy('JPY', '일본 엔', 100),
  eur('EUR', '유로', 1),
  cny('CNY', '중국 위안', 1);

  const Currency(this.code, this.label, this.unit);
  final String code;
  final String label;

  /// 환율을 고시하는 단위. 엔화는 100엔 기준이다.
  final int unit;
}

int toKrw(double amount, Currency c, double rate) => (amount / c.unit * rate).round();

final _comma = NumberFormat('#,##0', 'en_US');
String comma(num v) => _comma.format(v);
String won(int v) => '${comma(v)}원';

/// "120만", "1억 2,000만원", "1,200,000원" 을 원 단위로 읽는다.
int? parseWon(String input) {
  final s = input.replaceAll(RegExp(r'[,\s원]'), '');
  if (s.isEmpty) return null;
  if (RegExp(r'^\d{1,15}$').hasMatch(s)) return int.parse(s);
  final m = RegExp(r'^(?:(\d+(?:\.\d+)?)억)?(?:(\d+(?:\.\d+)?)만)?(\d+)?$').firstMatch(s);
  if (m == null) return null;
  final eok = double.parse(m[1] ?? '0'), man = double.parse(m[2] ?? '0');
  return (eok * 100000000).round() + (man * 10000).round() + int.parse(m[3] ?? '0');
}

/// 정수 비중. 최대 잔여 방식으로 합을 정확히 100 으로 맞춘다.
List<int> percentShares(List<int> values) {
  final total = values.fold(0, (a, b) => a + b);
  if (total <= 0) return List.filled(values.length, 0);
  final exact = [for (final v in values) v * 100 / total];
  final out = [for (final e in exact) e.floor()];
  final order = List.generate(values.length, (i) => i)
    ..sort((a, b) => (exact[b] - out[b]).compareTo(exact[a] - out[a]));
  final left = 100 - out.fold(0, (a, b) => a + b);
  for (var i = 0; i < left; i++) {
    out[order[i]]++;
  }
  return out;
}
