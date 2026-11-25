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
    listen('transactions', (d) => txns = [for (final (id, j) in d) Txn.fromJson(id, j)]..sort((a, b) => b.at.compareTo(a.at)));
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
    notifyListeners();
  }

  void _changed() => notifyListeners();

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
    return plan?.available(t, _uses) ?? 0;
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

  /// 저축 기록으로 본 월평균 저축액. 기록이 없으면 설정값.
  int get monthlySaving {
    final from = DateTime(today.year, today.month, today.day - 30);
    final s = savings.where((t) => t.at.isAfter(from)).fold(0, (a, t) => a + t.amount);
    return s > 0 ? s : settings?.saving ?? 0;
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
        final p = parseNotice(raw, at);
        if (p == null) {
          if (!looksLikePayment(raw)) return NoticeResult.ignored;
          if (pending.any((n) => n.raw == raw && n.app == app)) return NoticeResult.duplicate;
          await store.set('notices', store.newId(),
              PendingNotice(id: '', raw: raw.length > 2000 ? raw.substring(0, 2000) : raw, app: app, at: at).toJson());
          await _settle();
          return NoticeResult.pending;
        }
        if (p.cancelled) {
          final hit = txns.where((t) =>
              t.kind == TxnKind.expense && t.amount == p.amount && t.merchant == p.merchant && !t.at.isAfter(p.at));
          if (hit.isEmpty) return NoticeResult.ignored;
          await store.remove('transactions', hit.first.id);
          await _settle();
          return NoticeResult.cancelled;
        }
        final dup = txns.any((t) =>
            t.kind == TxnKind.expense && t.source != '직접 입력' && isDuplicate(t.asNotice, t.source, p, app));
        if (dup) return NoticeResult.duplicate;
        await _put(Txn(
            id: store.newId(), kind: TxnKind.expense, amount: p.amount, merchant: p.merchant,
            category: categorize(p.merchant), at: p.at, source: app, confirmed: false));
        return NoticeResult.recorded;
      });

  Future<void> addTxn(TxnKind kind, int amount, String merchant, Category category, DateTime at, {String source = '직접 입력'}) =>
      _serial(() => _put(Txn(
          id: store.newId(), kind: kind, amount: amount, merchant: merchant, category: category, at: at, source: source)));

  Future<void> _put(Txn t) async {
    if (t.amount <= 0) throw ArgumentError('금액은 1원 이상이어야 해요');
    final wasOver = over;
    final newDay = !recordDays.contains(dateOnly(t.at));
    await store.set('transactions', t.id, t.toJson());
    await _settle();
    await _award((newDay ? 10 : 2) + (t.kind == TxnKind.saving ? 20 : 0));
    if (!wasOver && over && t.kind == TxnKind.expense && dateOnly(t.at) == today) {
      _alerts.add(AppAlert(AlertKind.overBudget, '오늘 생활비를 ${won(-todayLeft)} 넘었어요',
          '내일 쓸 수 있는 돈은 ${won(tomorrowBudget)}이에요'));
    }
  }

  Future<void> _award(int points) async {
    await store.mergeUser({'points': xp + points, 'currentLevel': levelOf(xp + points)});
    await _settle();
  }

  Future<void> updateTxn(Txn t) => store.set('transactions', t.id, t.toJson());
  Future<void> confirmTxn(Txn t) => updateTxn(t.copyWith(confirmed: true));
  Future<void> deleteTxn(String id) => store.remove('transactions', id);

  Future<void> resolveNotice(PendingNotice n, int amount, String merchant, Category c) async {
    await _serial(() => _put(Txn(
        id: store.newId(), kind: TxnKind.expense, amount: amount, merchant: merchant, category: c, at: n.at, source: n.app)));
    await store.remove('notices', n.id);
  }

  Future<void> dismissNotice(PendingNotice n) => store.remove('notices', n.id);

  static const savingAssetId = 'liqua-saving';

  /// 남은 생활비를 목표 저축으로 보낸다. 남은 돈보다 많이 보낼 수 없다.
  Future<int> sendLeftoverToSaving(int amount) => _serial(() async {
        final v = amount.clamp(0, todayLeft < 0 ? 0 : todayLeft);
        if (v == 0) return 0;
        await _put(Txn(
            id: store.newId(), kind: TxnKind.saving, amount: v, merchant: '목표 저축', category: Category.etc, at: now, source: leftoverSource));
        final old = assets.where((a) => a.id == savingAssetId);
        await store.set('assets', savingAssetId, {
          'name': 'Liqua 저축', 'category': 'deposit', 'quantity': 1,
          'purchasePrice': (old.isEmpty ? 0 : old.first.currentPrice) + v,
          'currentPrice': (old.isEmpty ? 0 : old.first.currentPrice) + v,
        });
        await _settle();
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
    _alerts.add(AppAlert(AlertKind.milestone, '목표의 $m%를 모았어요',
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
        if (sharpDrop) {
          _alerts.add(AppAlert(AlertKind.sharpDrop, '자산이 하루 만에 ${won(previousSnapshot!.total - total)} 줄었어요', '자산 탭에서 바뀐 항목을 확인해 보세요'));
        }
      });

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _alerts.close();
    super.dispose();
  }
}
