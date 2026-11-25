import 'package:cloud_firestore/cloud_firestore.dart';
class Asset {
  const Asset({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.purchasePrice,
    required this.currentPrice,
    this.memo,
    this.createdAt,
    this.updatedAt,
  });

  static const categories = <String>['cash', 'deposit', 'stock', 'etf', 'fx', 'crypto', 'other'];

  static const categoryLabels = <String, String>{
    'stock': '주식',
    'cash': '현금',
    'deposit': '예금',
    'fx': '외화',
    'etf': 'ETF',
    'crypto': '가상자산',
    'other': '기타',
  };

  final String id;
  final String name;
  final String category;
  final double quantity;
  final double purchasePrice;
  final double currentPrice;
  final String? memo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  double get valuation => quantity * currentPrice;

  String get categoryLabel => categoryLabels[category] ?? category;

  factory Asset.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Asset(
      id: doc.id,
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? 'other',
      quantity: (data['quantity'] as num?)?.toDouble() ?? 0,
      purchasePrice: (data['purchasePrice'] as num?)?.toDouble() ?? 0,
      currentPrice: (data['currentPrice'] as num?)?.toDouble() ?? 0,
      memo: data['memo'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory Asset.fromJson(String id, Map<String, dynamic> data) => Asset(
    id: id,
    name: data['name'] as String? ?? '',
    category: data['category'] as String? ?? 'other',
    quantity: (data['quantity'] as num?)?.toDouble() ?? 0,
    purchasePrice: (data['purchasePrice'] as num?)?.toDouble() ?? 0,
    currentPrice: (data['currentPrice'] as num?)?.toDouble() ?? 0,
    memo: data['memo'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category,
    'quantity': quantity,
    'purchasePrice': purchasePrice,
    'currentPrice': currentPrice,
    if (memo != null) 'memo': memo,
  };

  static String? validate({
    required String name,
    required String category,
    required double? quantity,
    required double? purchasePrice,
    required double? currentPrice,
  }) {
    if (name.trim().isEmpty) return '자산 이름을 입력하세요.';
    if (!categories.contains(category)) return '자산 종류를 선택하세요.';
    if (quantity == null) return '수량을 숫자로 입력하세요.';
    if (quantity < 0) return '수량은 0보다 작을 수 없습니다.';
    if (purchasePrice == null) return '매입 단가를 숫자로 입력하세요.';
    if (purchasePrice < 0) return '매입 단가는 0보다 작을 수 없습니다.';
    if (currentPrice == null) return '현재 단가를 숫자로 입력하세요.';
    if (currentPrice < 0) return '현재 단가는 0보다 작을 수 없습니다.';
    return null;
  }
}

String formatWon(double value) {
  final negative = value < 0;
  final digits = value.abs().round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}$buffer원';
}
