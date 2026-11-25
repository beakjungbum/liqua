import 'dart:async';

import 'package:flutter/foundation.dart' hide Category;
import 'package:mm_app/domain/budget.dart';
import 'package:mm_app/domain/growth.dart';
import 'package:mm_app/domain/insight.dart';
import 'package:mm_app/domain/money.dart';
import 'package:mm_app/domain/notice_parser.dart';
import 'package:mm_app/models/asset.dart';

import 'models.dart';
import 'store.dart';

enum NoticeResult { recorded, duplicate, cancelled, pending, ignored }

enum AlertKind { overBudget, sharpDrop, milestone }

class AppAlert {
  const AppAlert(this.kind, this.title, this.body);
  final AlertKind kind;
  final String title, body;
}

/// 화면이 보는 상태 하나. 숫자는 전부 여기서 domain 함수로 계산한다.
class AppModel extends ChangeNotifier {
  AppModel(this.store, {DateTime Function()? clock, this.demo = false}) : _clock = clock ?? DateTime.now {
    void listen(String c, void Function(List<Doc>) f) => _subs.add(store.watch(c).listen((d) {
          f(d);
          _loaded.add(c);
          _changed();
        }, onError: _fail));
    listen('transactions', (d) {
      final all = [for (final (id, j) in d) Txn.fromJson(id, j)]..sort((a, b) => b.at.compareTo(a.at));
      txns = [for (final t in all) if (t.cancelledAt == null) t];
      _cancelled = [for (final t in all) if (t.cancelledAt != null) t];
    });
    listen('assets', (d) => assets = [for (final (id, j) in d) Asset.fromJson(id, j)]..sort((a, b) => b.valuation.compareTo(a.valuation)));
    listen('fixed', (d) => fixed = [for (final (id, j) in d) FixedExpense.fromJson(id, j)]..sort((a, b) => a.day.compareTo(b.day)));
    listen('notices', (d) => pending = [for (final (id, j) in d) PendingNotice.fromJson(id, j)]..sort((a, b) => b.at.compareTo(a.at)));
    listen('snapshots', (d) => snapshots = [for (final (_, j) in d) Snapshot.fromJson(j)]..sort((a, b) => a.at.compareTo(b.at)));
    _subs.add(store.watchUser().listen((u) {
      target = (u['targetAmount'] as num?)?.toInt() ?? 0;
      xp = (u['points'] as num?)?.toInt() ?? 0;
      name = (u['displayName'] as String?) ?? '';
      profile = Profile.fromJson(u['profile']);
      settings = PlanSettings.fromJson(u['plan']);
      celebrated = {for (final m in (u['celebrated'] as List? ?? const [])) (m as num).toInt()};
      completedGoals = ((u['growth'] as Map?)?['completedGoals'] as num?)?.toInt() ?? 0;
      _loaded.add('#user');
      _changed();
    }, onError: _fail));
  }

  final Store store;
  final bool demo;
  final DateTime Function() _clock;
  final _subs = <StreamSubscription<Object?>>[];
  final _loaded = <String>{};
  final _alerts = StreamController<AppAlert>.broadcast();
  var _busy = Future<void>.value();

  List<Txn> txns = const [];
  List<Txn> _cancelled = const [];
  var disposed = false;
  DateTime? _dropAlerted;
  List<Asset> assets = const [];
  List<FixedExpense> fixed = const [];
  List<PendingNotice> pending = const [];
  List<Snapshot> snapshots = const [];
  Set<int> celebrated = const {};
  Profile profile = const Profile();
  PlanSettings? settings;
  int target = 0, xp = 0, completedGoals = 0;
  String name = '';
  Object? error;

  Stream<AppAlert> get alerts => _alerts.stream;
  bool get ready => _loaded.length == 6;
  DateTime get now => _clock();
  DateTime get today => dateOnly(now);

  void _fail(Object e) {
    error = e;
    _changed();
  }

  void _changed() {
    if (!disposed) notifyListeners();
  }

  // ── 계산 ────────────────────────────────────────────
  int get total => assets.fold(0, (a, x) => a + x.valuation.round());
  double get percent => goalPercent(total, target);
  bool get onboarded => profile.complete && settings != null && target > 0;

  Iterable<Txn> get expenses => txns.where((t) => t.kind == TxnKind.expense);
  Iterable<Txn> get savings => txns.where((t) => t.kind == TxnKind.saving);
  List<Spend> get spends => [for (final t in expenses) Spend(t.amount, t.category, t.at)];

  Map<DateTime, DayUse> get _uses {
    final spent = <DateTime, int>{}, saved = <DateTime, int>{};
    for (final t in txns) {
      final d = dateOnly(t.at);
      // 고정지출은 생활비에서 이미 뺐으므로 다시 세지 않는다.
      if (t.kind == TxnKind.expense && t.category != Category.fixed) spent[d] = (spent[d] ?? 0) + t.amount;
      if (t.kind == TxnKind.saving && t.source == leftoverSource) saved[d] = (saved[d] ?? 0) + t.amount;
    }
    return {
      for (final d in {...spent.keys, ...saved.keys}) d: DayUse(spent: spent[d] ?? 0, toSaving: saved[d] ?? 0)
    };
  }

  static const leftoverSource = '남은 생활비';

  BudgetPlan? get plan => settings?.planFor(now, fixed);
  int get todayBudget => plan?.available(today, _uses) ?? 0;
  int get todayCarry => plan?.carry(today, _uses) ?? 0;
  int get todaySpent => _uses[today]?.spent ?? 0;
  int get todaySaved => _uses[today]?.toSaving ?? 0;
  int get todayLeft => todayBudget - todaySpent - todaySaved;
  int get daysLeft => plan == null ? 0 : plan!.days - daysBetween(plan!.start, today);
  bool get over => settings != null && todayLeft < 0;
  int get tomorrowBudget {
    final t = DateTime(today.year, today.month, today.day + 1);
    return settings?.planFor(t, fixed).available(t, _uses) ?? 0;
  }

  Set<DateTime> get recordDays => {for (final t in txns) dateOnly(t.at)};
  int get streakDays => streak(recordDays, today);
  PetStage get stage => petStage(
      onboarded: onboarded,
      savings: savings.length,
      recordDays7: recordDays7(recordDays, today),
      percent: percent,
      completedGoals: completedGoals);
  int get level => levelOf(xp);

  List<(Category, int)> get monthByCategory => byCategory(spends, now);
  int get monthTotal => monthByCategory.fold(0, (a, e) => a + e.$2);
  List<Advice> get advices => advise(spends, now, plan?.base(today) ?? 0);

  Snapshot? get previousSnapshot {
    final old = snapshots.where((s) => dateOnly(s.at).isBefore(today));
    return old.isEmpty ? null : old.last;
  }

  bool get sharpDrop {
    final p = previousSnapshot;
    return p != null && daysBetween(p.at, today) == 1 && isSharpDrop(p.total, total);
  }

  /// 먼저 저축할 금액에 최근 30일 추가 저축을 더한 값.
  int get monthlySaving {
    final from = DateTime(today.year, today.month, today.day - 30);
    final extra = savings.where((t) => t.at.isAfter(from)).fold(0, (a, t) => a + t.amount);
    return (settings?.saving ?? 0) + extra;
  }

  void _alert(AppAlert a) {
    if (!disposed) _alerts.add(a);
  }

  // ── 변경 ────────────────────────────────────────────
  /// 앞 작업이 끝난 뒤 순서대로 처리해 중복 검사와 경고가 엇갈리지 않게 한다.
  Future<T> _serial<T>(Future<T> Function() f) {
    final r = _busy.then((_) => f());
    _busy = r.then((_) {}, onError: (_) {});
    return r;
  }

  Future<void> _settle() => Future<void>.delayed(Duration.zero);

  Future<NoticeResult> handleNotice(String raw, {required String app, required DateTime at}) => _serial(() async {
        final p = parseNotice(raw, at, app: app);
        if (p == null) {
          if (!looksLikePayment(raw, app: app)) return NoticeResult.ignored;
          return _keepPending(raw, app, at);
        }
        if (p.cancelled) {
          bool same(Txn t) => t.kind == TxnKind.expense && t.amount == p.amount && sameMerchant(t.merchant, p.merchant);
          if (_cancelled.any((t) => same(t) && (t.cancelSource == app ? t.cancelledAt == p.at : t.cancelledAt!.difference(p.at).abs() <= const Duration(minutes: 3)))) {
            return NoticeResult.duplicate;
          }
          final hit = txns.where((t) => same(t) && !t.at.isAfter(p.at));
          if (hit.isEmpty) return _keepPending(raw, app, at);
          await store.set('transactions', hit.first.id, hit.first.copyWith(cancelledAt: p.at, cancelSource: app).toJson());
          await _settle();
          return NoticeResult.cancelled;
        }
        final dup = [...txns, ..._cancelled].any((t) =>
            t.kind == TxnKind.expense && t.source != '직접 입력' && isDuplicate(t.asNotice, t.source, p, app));
        if (dup) return NoticeResult.duplicate;
        await _put(Txn(
            id: store.newId(), kind: TxnKind.expense, amount: p.amount, merchant: p.merchant,
            category: _isFixed(p) ? Category.fixed : categorize(p.merchant), at: p.at, source: app, confirmed: false));
        return NoticeResult.recorded;
      });

  Future<NoticeResult> _keepPending(String raw, String app, DateTime at) async {
    if (pending.any((n) => n.raw == raw && n.app == app && n.at.difference(at).abs() <= const Duration(minutes: 3))) return NoticeResult.duplicate;
    await store.set('notices', store.newId(),
        PendingNotice(id: '', raw: raw.length > 2000 ? raw.substring(0, 2000) : raw, app: app, at: at).toJson());
    await _settle();
    return NoticeResult.pending;
  }

  /// 등록한 고정지출이 실제로 빠져나간 알림인가. 이름, 금액, 날짜가 모두 맞아야 한다.
  bool _isFixed(ParsedNotice p) => fixed.any((f) {
        if (f.amount != p.amount || !sameMerchant(f.name, p.merchant)) return false;
        final from = DateTime(p.at.year, p.at.month, p.at.day - 3);
        return daysBetween(from, f.nextDue(from)) <= 6;
      });

  Future<void> addTxn(TxnKind kind, int amount, String merchant, Category category, DateTime at, {String source = '직접 입력'}) =>
      _serial(() => _put(Txn(
          id: store.newId(), kind: kind, amount: amount, merchant: merchant, category: category, at: at, source: source)));

  Future<void> _put(Txn t, {List<Op> also = const []}) async {
    if (t.amount <= 0) throw ArgumentError('금액은 1원 이상이어야 해요');
    final wasOver = over;
    final newDay = !recordDays.contains(dateOnly(t.at));
    await store.commit([Op.set('transactions', t.id, t.toJson()), _points((newDay ? 10 : 2) + (t.kind == TxnKind.saving ? 20 : 0)), ...also]);
    await _settle();
    if (!wasOver && over && t.kind == TxnKind.expense && dateOnly(t.at) == today) {
      _alert(AppAlert(AlertKind.overBudget, '오늘 생활비를 ${won(-todayLeft)} 넘었어요',
          tomorrowBudget > 0 ? '내일 쓸 수 있는 돈은 ${won(tomorrowBudget)}이에요' : '내일 생활비까지 다 썼어요. 부족한 ${won(-tomorrowBudget)}은 그다음 날에서 빠져요'));
    }
  }

  Future<void> _award(int points) async {
    await store.commit([_points(points)]);
    await _settle();
  }

  Op _points(int n) => Op.user({'points': Inc(n), 'currentLevel': levelOf(xp + n)});

  Future<void> updateTxn(Txn t) => _serial(() async {
        final old = txns.where((x) => x.id == t.id);
        if (old.isEmpty) throw ArgumentError('이미 취소되었거나 지워진 기록이에요');
        if (_leftover(old.first) && (old.first.amount != t.amount || !_leftover(t))) {
          throw ArgumentError('저축 기록은 금액을 고칠 수 없어요. 지우고 다시 보내 주세요.');
        }
        await store.set('transactions', t.id, t.toJson());
        await _settle();
      });

  bool _leftover(Txn t) => t.kind == TxnKind.saving && t.source == leftoverSource;
  Future<void> confirmTxn(Txn t) => updateTxn(t.copyWith(confirmed: true));

  Future<void> refresh() => store.refresh();

  /// 밀어서 지운 기록을 그대로 되살린다.
  Future<void> restoreTxn(Txn t) => store.set('transactions', t.id, t.toJson());

  /// 최근 30일 동안 자주 쓴 분류부터.
  List<Category> get frequentCategories {
    final from = DateTime(today.year, today.month, today.day - 30);
    final n = <Category, int>{};
    for (final t in expenses.where((t) => t.at.isAfter(from))) {
      n[t.category] = (n[t.category] ?? 0) + 1;
    }
    final order = [...Category.values]..sort((a, b) {
        final d = (n[b] ?? 0) - (n[a] ?? 0);
        return d != 0 ? d : a.index - b.index;
      });
    return order.take(4).toList();
  }

  /// 저축 기록을 지우면 저축 자산에 더했던 금액도 되돌린다.
  Future<void> deleteTxn(String id) => _serial(() async {
        final t = txns.where((x) => x.id == id).firstOrNull;
        final a = assets.where((x) => x.id == savingAssetId).firstOrNull;
        await store.commit([
          Op.remove('transactions', id),
          if (t != null && _leftover(t) && a != null) _moveSaving(a, t.amount > a.valuation ? -a.valuation : -t.amount),
        ]);
        await _settle();
      });

  Op _moveSaving(Asset a, num v) => Op.merge('assets', a.id, v < 0 && -v >= a.valuation
      ? {'currentPrice': 0, 'purchasePrice': 0}
      : a.quantity > 0
      ? {'currentPrice': Inc(v / a.quantity), 'purchasePrice': Inc(v < 0 && a.purchasePrice < -v / a.quantity ? -a.purchasePrice : v / a.quantity)}
      : {'quantity': 1, 'currentPrice': v, 'purchasePrice': v});

  Future<void> resolveNotice(PendingNotice n, int amount, String merchant, Category c) async {
    await _serial(() => _put(
        Txn(id: store.newId(), kind: TxnKind.expense, amount: amount, merchant: merchant, category: c, at: n.at, source: n.app),
        also: [Op.remove('notices', n.id)]));
  }

  Future<void> dismissNotice(PendingNotice n) => store.remove('notices', n.id);

  static const savingAssetId = 'liqua-saving';

  /// 남은 생활비를 목표 저축으로 보낸다. 남은 돈보다 많이 보낼 수 없다.
  Future<int> sendLeftoverToSaving(int amount) => _serial(() async {
        final v = amount.clamp(0, todayLeft < 0 ? 0 : todayLeft);
        if (v == 0) return 0;
        final old = assets.where((a) => a.id == savingAssetId).firstOrNull;
        await _put(
            Txn(id: store.newId(), kind: TxnKind.saving, amount: v, merchant: '목표 저축', category: Category.etc, at: now, source: leftoverSource),
            also: [
              old == null
                  ? Op.merge('assets', savingAssetId, {'name': 'Liqua 저축', 'category': 'deposit', 'quantity': 1, 'purchasePrice': Inc(v), 'currentPrice': Inc(v)})
                  : _moveSaving(old, v)
            ]);
        await _milestones();
        return v;
      });

  Future<void> saveAsset(Asset a) => _serial(() async {
        final isNew = a.id.isEmpty;
        await store.set('assets', isNew ? store.newId() : a.id, a.toJson());
        await _settle();
        if (isNew) await _award(10);
        await _milestones();
      });
  /// 시세만 바꾼다. 그사이 고친 다른 값은 건드리지 않는다.
  Future<void> updatePrice(String id, double price) => _serial(() async {
        if (!assets.any((a) => a.id == id)) return;
        await store.commit([Op.merge('assets', id, {'currentPrice': price})]);
        await _settle();
        await _milestones();
      });
  Future<void> deleteAsset(String id) => store.remove('assets', id);

  Future<void> _milestones() async {
    if (!onboarded) return;
    final fresh = newMilestones(percent, celebrated);
    if (fresh.isEmpty) return;
    final done = fresh.contains(100) ? completedGoals + 1 : completedGoals;
    await store.mergeUser({
      'celebrated': [...celebrated, ...fresh],
      'growth': {'completedGoals': done},
    });
    await _settle();
    await _award(50 * fresh.length);
    final m = fresh.last;
    _alert(AppAlert(AlertKind.milestone, '목표의 $m%를 모았어요',
        m == 100 ? '왕관을 받았어요. 다음 목표를 정해 볼까요?' : '펫이 경험치 ${50 * fresh.length}을 받았어요'));
  }

  /// 새 목표를 정하면 축하 기록을 처음부터 다시 센다. 이미 지난 단계는 축하하지 않는다.
  Future<void> setTarget(int amount) => _serial(() async {
        if (amount <= 0) throw ArgumentError('목표는 1원 이상이어야 해요');
        if (amount == target) return;
        final pct = goalPercent(total, amount);
        await store.mergeUser({'targetAmount': amount, 'celebrated': [for (final m in milestones) if (pct >= m) m]});
        await _settle();
      });

  Future<void> saveSettings(PlanSettings s) => store.mergeUser({'plan': s.toJson()});
  Future<void> saveProfile(Profile p) => store.mergeUser({'profile': p.toJson()});
  Future<void> saveFixed(FixedExpense f) => store.set('fixed', f.id.isEmpty ? store.newId() : f.id, f.toJson());
  Future<void> deleteFixed(String id) => store.remove('fixed', id);

  /// 하루 한 번 총자산을 남긴다. 급감이면 알린다.
  Future<void> snapshotToday() => _serial(() async {
        if (!ready || assets.isEmpty) return;
        final id = '${today.year}-${'${today.month}'.padLeft(2, '0')}-${'${today.day}'.padLeft(2, '0')}';
        await store.set('snapshots', id, {'at': now, 'total': total});
        await _settle();
        if (sharpDrop && _dropAlerted != today) {
          _dropAlerted = today;
          _alert(AppAlert(AlertKind.sharpDrop, '자산이 하루 만에 ${won(previousSnapshot!.total - total)} 줄었어요', '자산 탭에서 바뀐 항목을 확인해 보세요'));
        }
      });

  void reportError(Object e) => _fail(e);

  @override
  void dispose() {
    disposed = true;
    for (final s in _subs) {
      s.cancel();
    }
    _alerts.close();
    super.dispose();
  }
}
