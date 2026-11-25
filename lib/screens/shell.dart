import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mm_app/data/app_model.dart';
import 'package:mm_app/data/store.dart';
import 'package:mm_app/screens/asset_screen.dart';
import 'package:mm_app/screens/book_screen.dart';
import 'package:mm_app/screens/goal_screen.dart';
import 'package:mm_app/screens/home_screen.dart';
import 'package:mm_app/services/device_service.dart';
import 'package:mm_app/theme/app_theme.dart';
import 'package:mm_app/ui/widgets.dart';

/// 로그인 없이 알림 수신을 시험할 때만 켠다: --dart-define=CAPTURE_IN_DEMO=true
const captureInDemo = bool.fromEnvironment('CAPTURE_IN_DEMO');

class Shell extends StatefulWidget {
  const Shell({super.key, required this.onExit, this.initial = 0});
  final VoidCallback onExit;
  final int initial;
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  late var index = widget.initial;
  late final AppModel m;
  StreamSubscription<AppAlert>? sub;
  String? fixedKey;

  @override
  void initState() {
    super.initState();
    m = AppScope.read(context);
    WidgetsBinding.instance.addObserver(this);
    sub = m.alerts.listen(onAlert);
    m.addListener(reschedule);
    final d = DeviceService.instance;
    // 둘러보기에서는 실제 알림을 읽지 않는다.
    if (!m.demo || captureInDemo) {
      d.setOwner(m.demo ? 'demo' : uidOf(m));
      d.onArrived(() => d.drain(m));
    }
    start();
  }

  Future<void> start() async {
    try {
      await m.snapshotToday();
      if (!m.demo || captureInDemo) await DeviceService.instance.drain(m);
      reschedule();
    } catch (e) {
      debugPrint('시작 작업 실패: $e');
    }
  }

  Object? shown;
  void reschedule() {
    if (m.error != null && m.error != shown) {
      shown = m.error;
      final e = m.error!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) toast(context, saveError(e));
      });
    }
    if (m.demo) return;
    final key = [m.today.toString(), for (final f in m.fixed) '${f.id}${f.name}${f.amount}${f.day}${f.remind}'].join('|');
    if (key == fixedKey) return;
    fixedKey = key;
    DeviceService.instance.schedule(m.fixed).catchError((Object e) => debugPrint('예약 실패: $e'));
  }

  String uidOf(AppModel m) => m.store is FirestoreStore ? (m.store as FirestoreStore).uid : 'demo';

  void onAlert(AppAlert a) {
    if (!m.demo || captureInDemo) DeviceService.instance.alert(a).catchError((Object e) => debugPrint('알림 실패: $e'));
    if (!mounted) return;
    sheet<void>(
        context,
        Column(children: [
          Mascot(stage: m.stage, size: 150, percent: m.percent, crowns: m.completedGoals, worried: a.kind != AlertKind.milestone),
          SizedBox(height: 8),
          Text(a.title, textAlign: TextAlign.center, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: a.kind == AlertKind.milestone ? AppColors.deep : AppColors.accent)),
          SizedBox(height: 8),
          Text(a.body, textAlign: TextAlign.center, style: TextStyle(color: AppColors.sub)),
          SizedBox(height: 16),
          Builder(builder: (c) => SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(c), child: Text('확인했어요')))),
        ]));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      start();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    sub?.cancel();
    for (final c in scrolls) {
      c.dispose();
    }
    DeviceService.instance.onArrived(null);
    m.removeListener(reschedule);
    super.dispose();
  }

  final scrolls = [for (var i = 0; i < 4; i++) ScrollController()];

  void select(int i) {
    if (i != index) {
      setState(() => index = i);
      return;
    }
    final c = scrolls[i];
    if (!c.hasClients) return;
    MediaQuery.disableAnimationsOf(context) ? c.jumpTo(0) : c.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
  }

  /// 화면마다 가장 중요한 행동 하나를 늘 같은 자리에 둔다.
  Widget _primary(AppModel m) {
    final (icon, label, VoidCallback run) = switch (index) {
      2 => (Icons.add_rounded, '자산 추가', () => sheet<void>(context, AssetForm(fx: lastFx))),
      3 when m.todayLeft > 0 => (Icons.savings_rounded, '남은 돈 저축', () => push(context, BudgetDetail())),
      3 => (Icons.flag_rounded, '목표 수정', () => sheet<void>(context, TargetForm())),
      _ => (Icons.add_rounded, '기록', () => sheet<void>(context, TxnForm())),
    };
    return FloatingActionButton.extended(
        onPressed: run, icon: Icon(icon), label: Text(label, style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.orange, foregroundColor: AppColors.ink, elevation: 2, shape: StadiumBorder());
  }

  @override
  Widget build(BuildContext context) {
    final m = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
          bottom: false,
          child: IndexedStack(index: index, children: [
            HomeScreen(onExit: widget.onExit, go: (i) => setState(() => index = i), scroll: scrolls[0]),
            BookScreen(scroll: scrolls[1]),
            AssetScreen(scroll: scrolls[2]),
            GoalScreen(scroll: scrolls[3]),
          ])),
      floatingActionButton: _primary(m),
      bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: select,
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          indicatorColor: AppColors.mist,
          destinations: [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: '홈'),
            NavigationDestination(
                icon: Badge(isLabelVisible: m.pending.isNotEmpty, backgroundColor: AppColors.accent, child: Icon(Icons.receipt_long_outlined)),
                selectedIcon: Icon(Icons.receipt_long_rounded), label: '가계부'),
            NavigationDestination(icon: Icon(Icons.savings_outlined), selectedIcon: Icon(Icons.savings_rounded), label: '자산'),
            NavigationDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag_rounded), label: '목표'),
          ]),
    );
  }
}
