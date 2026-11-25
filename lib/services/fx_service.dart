import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mm_app/domain/money.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FxQuote {
  const FxQuote(this.rates, this.date, this.source, {this.previous = const {}, this.stale = false});

  /// 통화 1단위당 원화. 엔화도 1엔 기준이다.
  final Map<String, double> rates, previous;
  final String date, source;
  final bool stale;
  double? change(String code) {
    final a = previous[code], b = rates[code];
    return a == null || b == null || a == 0 ? null : (b - a) / a * 100;
  }

  Map<String, dynamic> toJson() => {'rates': rates, 'previous': previous, 'date': date, 'source': source};
  factory FxQuote.fromJson(Map<String, dynamic> j, {bool stale = false}) => FxQuote(
      _rates(j['rates']), j['date'] as String, j['source'] as String,
      previous: _rates(j['previous']), stale: stale);
  static Map<String, double> _rates(Object? m) =>
      {for (final e in (m as Map? ?? const {}).entries) '${e.key}': (e.value as num).toDouble()};
}

/// 한국수출입은행 응답. 엔화는 "JPY(100)" 처럼 단위가 붙는다.
Map<String, double> parseExim(List<dynamic> rows) {
  final out = <String, double>{};
  for (final r in rows.cast<Map<String, dynamic>>()) {
    final m = RegExp(r'^([A-Z]{3})(?:\((\d+)\))?$').firstMatch('${r['cur_unit']}');
    final v = double.tryParse('${r['deal_bas_r']}'.replaceAll(',', ''));
    if (m != null && v != null) out[m[1]!] = v / int.parse(m[2] ?? '1');
  }
  return out;
}

/// ECB 기준(KRW 로 나눈 값)을 통화 1단위당 원화로 뒤집는다.
Map<String, double> parseEcb(Map<String, dynamic> krwBased) =>
    {for (final e in krwBased.entries) if ((e.value as num) > 0) e.key: 1 / (e.value as num)};

class FxService {
  FxService({http.Client? client, this.eximKey = const String.fromEnvironment('EXIM_KEY')}) : _c = client ?? http.Client();
  final http.Client _c;
  final String eximKey;
  static const _cacheKey = 'fx';

  Future<FxQuote?> load() async {
    final p = await SharedPreferences.getInstance();
    try {
      final q = eximKey.isEmpty ? await _ecb() : await _exim();
      await p.setString(_cacheKey, jsonEncode(q.toJson()));
      return q;
    } catch (_) {
      final s = p.getString(_cacheKey);
      return s == null ? null : FxQuote.fromJson(jsonDecode(s) as Map<String, dynamic>, stale: true);
    }
  }

  Future<dynamic> _get(Uri u) async {
    final r = await _c.get(u).timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) throw StateError('HTTP ${r.statusCode}');
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  String _d(DateTime d) => '${d.year}-${'${d.month}'.padLeft(2, '0')}-${'${d.day}'.padLeft(2, '0')}';

  /// 주말과 공휴일에는 빈 목록이 오므로 값이 있는 날까지 거슬러 간다.
  Future<FxQuote> _exim() async {
    final days = <(String, Map<String, double>)>[];
    for (var i = 0; i < 12 && days.length < 2; i++) {
      final d = _d(DateTime.now().subtract(Duration(days: i)));
      final rows = await _get(Uri.https('oapi.koreaexim.go.kr', '/site/program/financial/exchangeJSON',
          {'authkey': eximKey, 'searchdate': d.replaceAll('-', ''), 'data': 'AP01'}));
      final m = parseExim(rows as List);
      if (m.isNotEmpty) days.add((d, m));
    }
    if (days.isEmpty) throw StateError('고시 환율 없음');
    return FxQuote(days[0].$2, days[0].$1, '한국수출입은행', previous: days.length > 1 ? days[1].$2 : const {});
  }

  Future<FxQuote> _ecb() async {
    final codes = [for (final c in Currency.values) c.code].join(',');
    final from = _d(DateTime.now().subtract(const Duration(days: 10)));
    final j = await _get(Uri.https('api.frankfurter.dev', '/v1/$from..', {'base': 'KRW', 'symbols': codes})) as Map<String, dynamic>;
    final rates = (j['rates'] as Map).cast<String, dynamic>();
    final days = rates.keys.toList()..sort();
    Map<String, double> at(String d) => parseEcb((rates[d] as Map).cast<String, dynamic>());
    return FxQuote(at(days.last), days.last, '유럽중앙은행(Frankfurter)',
        previous: days.length > 1 ? at(days[days.length - 2]) : const {});
  }
}
