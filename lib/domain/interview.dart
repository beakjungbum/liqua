import 'package:mm_app/data/models.dart';
import 'money.dart';

enum Ask { age, income, region, experience, risk, reason }

const questions = {
  Ask.age: ('만 나이가 어떻게 되세요?', <String>[]),
  Ask.income: ('한 달에 들어오는 돈은 얼마쯤인가요?', ['50만원', '120만원', '220만원']),
  Ask.region: ('어느 지역에 사세요?', ['서울', '경기', '인천', '부산']),
  Ask.experience: ('투자해 본 적이 있나요?', ['처음이에요', '조금 해봤어요', '꾸준히 하고 있어요']),
  Ask.risk: ('원금이 줄어들 수 있다면 어떠세요?', ['싫어요', '조금은 괜찮아요', '감수할 수 있어요']),
  Ask.reason: ('무엇을 위해 모으고 싶으세요?', ['비상금', '여행', '독립', '학비']),
};

const _regions = ['서울', '부산', '대구', '인천', '광주', '대전', '울산', '세종', '경기', '강원', '충북', '충남', '전북', '전남', '경북', '경남', '제주'];
const _city = {'안양': '경기', '수원': '경기', '성남': '경기', '고양': '경기', '용인': '경기', '부천': '경기', '안산': '경기', '군포': '경기', '의왕': '경기', '과천': '경기'};
const _long = {'충청북': '충북', '충청남': '충남', '전라북': '전북', '전라남': '전남', '경상북': '경북', '경상남': '경남'};

/// 자유로운 대답에서 값을 읽는다. 못 읽으면 null 이고 다시 묻는다.
Profile? answer(Profile p, Ask ask, String raw) {
  final s = raw.trim();
  Profile next({int? age, int? income, String? region, String? exp, String? risk, String? reason}) => Profile(
      age: age ?? p.age, monthlyIncome: income ?? p.monthlyIncome, region: region ?? p.region,
      experience: exp ?? p.experience, risk: risk ?? p.risk, goalReason: reason ?? p.goalReason);
  switch (ask) {
    case Ask.age:
      final m = RegExp(r'(?<!\d)(\d{1,3})(?!\d)').firstMatch(s);
      final v = m == null ? null : int.parse(m[1]!);
      return v == null || v < 14 || v > 100 ? null : next(age: v);
    case Ask.income:
      if (RegExp(r'없|0원').hasMatch(s) && !RegExp(r'[1-9]').hasMatch(s)) return next(income: 0);
      final m = RegExp(r'(?:\d+(?:\.\d+)?억)?\s*[\d,]+(?:\.\d+)?\s*만?\s*원?').firstMatch(s);
      final v = m == null ? null : parseWon(m[0]!);
      if (v == null) return null;
      // "120 정도" 처럼 단위를 뺀 작은 수는 만 원으로 본다.
      return next(income: v > 0 && v < 10000 ? v * 10000 : v);
    case Ask.region:
      for (final e in {..._long, ..._city}.entries) {
        if (s.contains(e.key)) return next(region: e.value);
      }
      for (final r in _regions) {
        if (s.contains(r)) return next(region: r);
      }
      return null;
    case Ask.experience:
      if (RegExp(r'꾸준|많|자주|오래').hasMatch(s)) return next(exp: '꾸준히');
      if (RegExp(r'처음|없|안\s*해|아니').hasMatch(s)) return next(exp: '처음');
      if (RegExp(r'조금|있|해\s*봤|네').hasMatch(s)) return next(exp: '조금');
      return null;
    case Ask.risk:
      if (RegExp(r'감수|괜찮아요|높').hasMatch(s) && !s.contains('조금')) return next(risk: '높음');
      if (RegExp(r'조금|보통').hasMatch(s)) return next(risk: '보통');
      if (RegExp(r'싫|안|낮|무서').hasMatch(s)) return next(risk: '낮음');
      return null;
    case Ask.reason:
      return s.isEmpty ? null : next(reason: s.length > 60 ? s.substring(0, 60) : s);
  }
}
