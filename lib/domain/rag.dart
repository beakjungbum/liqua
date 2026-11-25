/// 공식 자료 한 건. 본문은 [url] 을 직접 읽고 옮긴 것이다.
class Knowledge {
  const Knowledge({
    required this.id, required this.kind, required this.title, required this.body, required this.url,
    required this.source, required this.checkedAt, this.howTo, this.asOf, this.keywords = const [],
    this.minAge, this.maxAge, this.maxMonthlyIncome, this.region = '전국', this.risk, this.endsAt,
  });
  final String id, kind, title, body, url, source, checkedAt, region;
  final String? howTo, asOf, risk;
  final List<String> keywords;
  final DateTime? endsAt;
  final int? minAge, maxAge, maxMonthlyIncome;

  factory Knowledge.fromJson(Map<String, dynamic> j) => Knowledge(
      id: j['id'] as String, kind: j['kind'] as String, title: j['title'] as String, body: j['body'] as String,
      url: j['url'] as String, source: j['source'] as String, checkedAt: j['checkedAt'] as String,
      howTo: j['howTo'] as String?, asOf: j['asOf'] as String?,
      keywords: [for (final k in (j['keywords'] as List? ?? const [])) '$k'],
      minAge: j['minAge'] as int?, maxAge: j['maxAge'] as int?, maxMonthlyIncome: j['maxMonthlyIncome'] as int?,
      region: j['region'] as String? ?? '전국', risk: j['risk'] as String?,
      endsAt: j['endsAt'] == null ? null : DateTime.parse(j['endsAt'] as String));
}

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^0-9a-z가-힣]'), '');

const _min = 3;

/// 질문과 겹치는 자료를 점수 순으로 찾는다. 겹치는 게 없으면 빈 목록이다.
List<Knowledge> search(String question, List<Knowledge> all, {int limit = 3}) {
  final q = _norm(question);
  if (q.length < 2) return const [];
  final scored = <(Knowledge, int)>[];
  for (final k in all) {
    var score = 0;
    for (final w in {...k.keywords, k.title}) {
      final n = _norm(w);
      if (n.length >= 2 && q.contains(n)) score += 2 + n.length;
    }
    for (final w in question.split(RegExp(r'\s+'))) {
      final n = _norm(w);
      if (n.length >= 3 && _norm(k.title).contains(n)) score += 3;
    }
    if (score >= _min) scored.add((k, score));
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final s in scored.take(limit)) s.$1];
}

/// 신청 기간이 끝난 자료를 뺀다.
List<Knowledge> open(List<Knowledge> all, DateTime now) =>
    [for (final k in all) if (k.endsAt == null || now.isBefore(k.endsAt!)) k];

/// 명시된 조건에 어긋나지 않는 혜택. 조건이 적히지 않은 항목은 남긴다.
List<Knowledge> eligible(List<Knowledge> all, {int? age, int? monthlyIncome, String? region}) => [
      for (final k in all)
        if (k.kind == 'benefit' &&
            (age == null || ((k.minAge ?? 0) <= age && age <= (k.maxAge ?? 200))) &&
            (monthlyIncome == null || k.maxMonthlyIncome == null || monthlyIncome <= k.maxMonthlyIncome!) &&
            (k.region == '전국' || region == null || k.region.startsWith(region) || region.startsWith(k.region)))
          k
    ];

/// 낮은 위험을 고른 사람에게 높은 위험을 먼저 보이지 않는다.
List<Knowledge> investFor(List<Knowledge> all, String? risk) {
  const order = ['낮음', '보통', '높음'];
  final cap = order.indexOf(risk ?? '낮음');
  return all.where((k) => k.kind == 'invest' && order.indexOf(k.risk ?? '높음') <= (cap < 0 ? 0 : cap)).toList()
    ..sort((a, b) => order.indexOf(a.risk!).compareTo(order.indexOf(b.risk!)));
}

const noEvidence = '확인된 정보 없음';

/// 특정 종목을 사고팔라는 답은 화면에 내지 않는다.
bool recommendsTrade(String s) {
  final t = s.replaceAll(RegExp(r'권하지|권유하지|추천하지'), '');
  return RegExp(r'(매수|매도)[^.]{0,8}(하세요|추천|권|좋)|(사|파|담으|투자하|매입하)세요|사는 (게|것이) 좋|꼭 사|무조건 사|사야 (해|합)').hasMatch(t);
}
