import 'package:mm_app/domain/budget.dart';
import 'package:mm_app/domain/notice_parser.dart';

typedef Json = Map<String, dynamic>;

int _int(Object? v, [int or = 0]) => v is num ? v.round() : or;
DateTime _date(Object? v) => v is DateTime ? v : DateTime.fromMillisecondsSinceEpoch(0);

enum TxnKind { expense, income, saving }

class Txn {
  const Txn({
    required this.id,
    required this.kind,
    required this.amount,
    required this.merchant,
    required this.category,
    required this.at,
    this.source = '직접 입력',
    this.confirmed = true,
  });
  final String id;
  final TxnKind kind;
  final int amount;
  final String merchant;
  final Category category;
  final DateTime at;
  final String source;
  final bool confirmed;

  factory Txn.fromJson(String id, Json j) => Txn(
        id: id,
        kind: j['income'] == true
            ? TxnKind.income
            : j['category'] == 'saving'
                ? TxnKind.saving
                : TxnKind.expense,
        amount: _int(j['amount']),
        merchant: j['merchant'] as String? ?? '',
        category: Category.values.asNameMap()[j['category']] ?? Category.etc,
        at: _date(j['at']),
        source: j['source'] as String? ?? '직접 입력',
        confirmed: j['confirmed'] as bool? ?? true,
      );

  Json toJson() => {
        'income': kind == TxnKind.income,
        'amount': amount,
        'merchant': merchant,
        'category': kind == TxnKind.saving ? 'saving' : category.name,
        'at': at,
        'source': source,
        'confirmed': confirmed,
      };

  Txn copyWith({int? amount, String? merchant, Category? category, DateTime? at, bool? confirmed}) => Txn(
      id: id, kind: kind, amount: amount ?? this.amount, merchant: merchant ?? this.merchant,
      category: category ?? this.category, at: at ?? this.at, source: source, confirmed: confirmed ?? this.confirmed);

  ParsedNotice get asNotice => ParsedNotice(amount: amount, merchant: merchant, at: at, cancelled: false);
}

/// 해석하지 못한 결제 알림. 「확인 필요」 목록에 남는다.
class PendingNotice {
  const PendingNotice({required this.id, required this.raw, required this.app, required this.at});
  final String id, raw, app;
  final DateTime at;
  factory PendingNotice.fromJson(String id, Json j) =>
      PendingNotice(id: id, raw: j['raw'] as String? ?? '', app: j['app'] as String? ?? '', at: _date(j['at']));
  Json toJson() => {'raw': raw, 'app': app, 'at': at};
}

class FixedExpense {
  const FixedExpense({required this.id, required this.name, required this.amount, required this.day, this.remind = true});
  final String id, name;
  final int amount, day;
  final bool remind;
  factory FixedExpense.fromJson(String id, Json j) => FixedExpense(
      id: id, name: j['name'] as String? ?? '', amount: _int(j['amount']),
      day: _int(j['day'], 1).clamp(1, 31), remind: j['remind'] as bool? ?? true);
  Json toJson() => {'name': name, 'amount': amount, 'day': day, 'remind': remind};

  DateTime nextDue(DateTime today) => nextPayday(DateTime(today.year, today.month, today.day - 1), day);
}

/// 생활비 설정. 수입일이 지나면 다음 기간으로 저절로 넘어간다.
class PlanSettings {
  const PlanSettings({required this.living, required this.saving, required this.start, this.payday});
  final int living, saving;
  final DateTime start;

  /// 매달 수입일. 없으면 30일 단위.
  final int? payday;

  static PlanSettings? fromJson(Object? j) => j is! Map
      ? null
      : PlanSettings(
          living: _int(j['living']), saving: _int(j['saving']), start: _date(j['start']),
          payday: j['payday'] is num ? _int(j['payday']).clamp(1, 31) : null);
  Json toJson() => {'living': living, 'saving': saving, 'start': start, 'payday': payday};

  BudgetPlan planFor(DateTime today, List<FixedExpense> fixed) {
    DateTime endOf(DateTime s) => payday == null ? DateTime(s.year, s.month, s.day + 30) : nextPayday(s, payday!);
    var s = dateOnly(start);
    var e = endOf(s);
    while (!e.isAfter(dateOnly(today))) {
      s = e;
      e = endOf(s);
    }
    final due = fixed.where((f) => f.nextDue(s).isBefore(e)).fold(0, (a, f) => a + f.amount);
    return BudgetPlan(living: living, fixed: due, saving: saving, start: s, days: daysBetween(s, e));
  }
}

class Profile {
  const Profile({this.age, this.monthlyIncome, this.region, this.experience, this.risk, this.goalReason});
  final int? age, monthlyIncome;
  final String? region, experience, risk, goalReason;

  bool get complete => age != null && monthlyIncome != null && region != null && experience != null && risk != null;

  factory Profile.fromJson(Object? j) => j is! Map
      ? const Profile()
      : Profile(
          age: j['age'] is num ? _int(j['age']) : null,
          monthlyIncome: j['monthlyIncome'] is num ? _int(j['monthlyIncome']) : null,
          region: j['region'] as String?, experience: j['experience'] as String?,
          risk: j['risk'] as String?, goalReason: j['goalReason'] as String?);
  Json toJson() => {
        'age': age, 'monthlyIncome': monthlyIncome, 'region': region,
        'experience': experience, 'risk': risk, 'goalReason': goalReason,
      };
}

class Snapshot {
  const Snapshot(this.at, this.total);
  final DateTime at;
  final int total;
  factory Snapshot.fromJson(Json j) => Snapshot(_date(j['at']), _int(j['total']));
}
