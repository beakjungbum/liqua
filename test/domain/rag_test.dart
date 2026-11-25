import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_app/domain/rag.dart';

Knowledge k(String id, {String kind = 'basics', String? title, List<String> kw = const [], int? min, int? max, int? inc, String region = '전국', String? risk}) =>
    Knowledge(id: id, kind: kind, title: title ?? id, body: 'b', url: 'https://e.kr', source: 's', checkedAt: 'd', keywords: kw, minAge: min, maxAge: max, maxMonthlyIncome: inc, region: region, risk: risk);
void main() {
  final all = [k('a', title: '예금자보호', kw: ['예금자보호', '예금 보호']), k('b', title: 'ETF', kw: ['ETF', '상장지수펀드'])];
  test('띄어쓰기가 달라도 찾는다', () => expect(search('예금자 보호 한도가 얼마야?', all).first.id, 'a'));
  test('대소문자 무시', () => expect(search('etf가 뭐야', all).first.id, 'b'));
  test('관련 없는 질문은 빈 목록', () {
    expect(search('오늘 점심 뭐 먹지', all), isEmpty);
    expect(search('', all), isEmpty);
  });
  test('혜택은 나이·소득·지역이 어긋나면 뺀다', () {
    final b = [k('x', kind: 'benefit', min: 19, max: 34, inc: 3000000, region: '경기')];
    expect(eligible(b, age: 21, monthlyIncome: 1200000, region: '경기'), hasLength(1));
    expect(eligible(b, age: 35, region: '경기'), isEmpty);
    expect(eligible(b, age: 18, region: '경기'), isEmpty);
    expect(eligible(b, age: 21, monthlyIncome: 3000001, region: '경기'), isEmpty);
    expect(eligible(b, age: 21, region: '서울'), isEmpty);
  });
  test('위험 성향보다 높은 투자 정보는 뺀다', () {
    final v = [k('h', kind: 'invest', risk: '높음'), k('l', kind: 'invest', risk: '낮음')];
    expect(investFor(v, '낮음').map((e) => e.id), ['l']);
    expect(investFor(v, '높음').map((e) => e.id), ['l', 'h']);
    expect(investFor(v, null).map((e) => e.id), ['l']);
  });
  test('신청이 끝난 자료는 추천과 답변에서 빠진다', () {
    final list = [for (final j in jsonDecode(File('assets/knowledge.json').readAsStringSync()) as List) Knowledge.fromJson(j as Map<String, dynamic>)];
    Iterable<String> ids(DateTime t) => open(list, t).map((e) => e.id);
    expect(ids(DateTime(2026, 12, 1, 17, 59)), contains('gyeonggi-youth-basic-income-2026-q4'));
    expect(ids(DateTime(2026, 12, 1, 18, 1)), isNot(contains('gyeonggi-youth-basic-income-2026-q4')));
    expect(ids(DateTime(2028)).length, list.length - 3);
  });
  test('매매 권유 문장을 잡는다', () {
    expect(recommendsTrade('삼성전자를 매수하세요'), isTrue);
    expect(recommendsTrade('ETF는 여러 종목을 담은 상품이에요'), isFalse);
  });
  test('자료 파일은 전부 출처가 있고 투자 항목엔 위험 등급이 있다', () {
    final list = [for (final j in jsonDecode(File('assets/knowledge.json').readAsStringSync()) as List) Knowledge.fromJson(j as Map<String, dynamic>)];
    expect(list.length, greaterThanOrEqualTo(15));
    expect(list.map((e) => e.id).toSet().length, list.length);
    for (final e in list) {
      expect(e.url, startsWith('https://'), reason: e.id);
      expect(e.source, isNotEmpty);
      if (e.kind == 'invest') expect(['낮음', '보통', '높음'], contains(e.risk), reason: e.id);
      expect(recommendsTrade(e.body), isFalse, reason: e.id);
    }
  });
}
