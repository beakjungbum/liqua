enum Category {
  food('식비'), cafe('카페'), transport('교통'), shopping('쇼핑'), living('생활'),
  health('건강'), culture('문화'), fixed('고정지출'), etc('기타');

  const Category(this.label);
  final String label;
}

class ParsedNotice {
  const ParsedNotice({required this.amount, required this.merchant, required this.at, required this.cancelled, this.timed = true});
  final int amount;
  final String merchant;
  final DateTime at;
  final bool cancelled;

  /// 알림 문구에 시각이 있었는가. 없으면 [at] 은 받은 시각이다.
  final bool timed;
}

final _amount = RegExp(r'(?<![\d,])(\d{1,3}(?:,\d{3})+|\d+)\s*원');
final _cumulative = RegExp(r'(?:총\s*)?(?:누적|잔액|한도|사용가능)[^\d\n]*[\d,]+\s*원?');
final _date = RegExp(r'(?<!\d)(\d{1,2})[/.](\d{1,2})\s+(\d{1,2}):(\d{2})');
final _issuer = RegExp(r'Web발신|카드|페이|뱅크|은행|토스');
final _ignore = RegExp(r'\(광고\)|거절|실패|입금|예정|결제일|인증번호|요청|하면|하세요|해야|했어(?!요)|했니|할까|특가|쿠폰|이벤트');
final _refund = RegExp(r'환불|부분\s*취소');
final _cancel = RegExp(r'취소');

/// 결제 알림으로 보이는가. 읽지 못했을 때 「확인 필요」 로 남길지 정한다.
bool looksLikePayment(String raw) => 
    !_ignore.hasMatch(raw) &&
    _amount.hasMatch(raw) &&
    (raw.contains('승인') || (raw.contains('결제') && _issuer.hasMatch(raw)));

/// 금액과 가맹점을 모두 확신할 때만 값을 낸다. 아니면 null.
ParsedNotice? parseNotice(String raw, DateTime receivedAt) {
  if (!looksLikePayment(raw) || _refund.hasMatch(raw)) return null;
  final text = raw.replaceAll(_cumulative, ' ');
  final am = _amount.firstMatch(text);
  if (am == null) return null;
  final amount = int.tryParse(am[1]!.replaceAll(',', ''));
  if (amount == null || amount <= 0) return null;
  final merchant = _merchant(text, am);
  if (merchant == null) return null;
  return ParsedNotice(
      amount: amount, merchant: merchant, at: _when(text, receivedAt), cancelled: _cancel.hasMatch(raw),
      timed: _date.hasMatch(text));
}

DateTime _when(String text, DateTime received) {
  final m = _date.firstMatch(text);
  if (m == null) return received;
  final [mo, d, h, mi] = [for (var i = 1; i <= 4; i++) int.parse(m[i]!)];
  if (mo < 1 || mo > 12 || d < 1 || d > 31 || h > 23 || mi > 59) return received;
  var at = DateTime(received.year, mo, d, h, mi);
  if (at.month != mo) return received;
  if (at.isAfter(received.add(const Duration(days: 1)))) at = DateTime(received.year - 1, mo, d, h, mi);
  return at;
}

String? _merchant(String text, RegExpMatch am) {
  // "쿠팡에서 18,900원을 결제"
  final before = RegExp(r'([^\n]+?)에서\s*$').firstMatch(text.substring(0, am.start));
  if (before != null) return _clean(before[1]!);
  final tail = text
      .substring(am.end)
      .replaceAll(_date, '\n')
      .replaceAll(RegExp(r'\(?일시불\)?|\(?\d+개월\)?|승인취소|승인|취소|결제(?:\s*완료)?|체크카드|신용카드|[|·]'), '\n');
  for (final line in tail.split('\n')) {
    final c = _clean(line);
    if (c != null) return c;
  }
  return null;
}

String? _clean(String s) {
  final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.length < 2 || t.length > 40 || !RegExp(r'[가-힣A-Za-z]').hasMatch(t)) return null;
  if (RegExp(r'^[가-힣]\*[가-힣]님?$').hasMatch(t)) return null;
  return t;
}

final _rules = <Category, RegExp>{
  Category.cafe: RegExp(r'스타벅스|커피|카페|투썸|이디야|빽다방|컴포즈|할리스|파리바게|뚜레쥬르'),
  Category.transport: RegExp(r'버스|지하철|택시|코레일|SRT|티머니|카카오T|주유|따릉이|철도', caseSensitive: false),
  Category.food: RegExp(
      r'(?:^|\s)CU(?:\s|$)|GS25|세븐일레븐|이마트24|편의점|맥도날드|버거|김밥|식당|치킨|피자|배달|요기요|쿠팡이츠|국밥|분식|떡볶이|마트',
      caseSensitive: false),
  Category.shopping: RegExp(r'쿠팡|무신사|올리브영|다이소|11번가|지마켓|네이버페이|백화점|아울렛|에이블리'),
  Category.health: RegExp(r'약국|병원|의원|치과|헬스|피트니스'),
  Category.culture: RegExp(r'CGV|메가박스|롯데시네마|교보문고|알라딘|예스24|넷플릭스|멜론|유튜브|노래방|PC방', caseSensitive: false),
  Category.living: RegExp(r'세탁|미용|헤어|통신|전기|가스|수도'),
};

Category categorize(String merchant) {
  for (final e in _rules.entries) {
    if (e.value.hasMatch(merchant)) return e.key;
  }
  return Category.etc;
}

bool sameMerchant(String a, String b) {
  final x = a.replaceAll(' ', ''), y = b.replaceAll(' ', '');
  return x.contains(y) || y.contains(x);
}

/// 같은 결제가 문자와 카카오톡으로 두 번 온 것인가.
/// 같은 앱에서 온 것은 시각과 가맹점까지 같을 때만 재전송으로 본다.
bool isDuplicate(ParsedNotice a, String sourceA, ParsedNotice b, String sourceB) {
  if (a.amount != b.amount || a.cancelled != b.cancelled) return false;
  if (sourceA == sourceB) {
    if (a.merchant != b.merchant) return false;
    // 시각 없는 알림은 앱이 같은 알림을 다시 띄울 수 있어 1분까지 같은 것으로 본다.
    return b.timed ? a.at == b.at : a.at.difference(b.at).abs() <= const Duration(minutes: 1);
  }
  return sameMerchant(a.merchant, b.merchant) && a.at.difference(b.at).abs() <= const Duration(minutes: 3);
}
