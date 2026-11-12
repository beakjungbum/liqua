class Entry {
  final bool income; // 참(true): 수입, 거짓(false): 지출
  final String category; // '식비', '교통', '생활'
  final int amount; // 금액 (원)
  const Entry({
    required this.income,
    required this.category,
    required this.amount,
    });
  }