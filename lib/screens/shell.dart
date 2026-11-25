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

  void reschedule() {
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
          const SizedBox(height: 6),
          Text(a.title, textAlign: TextAlign.center, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: a.kind == AlertKind.milestone ? AppColors.deep : AppColors.accent)),
          const SizedBox(height: 6),
          Text(a.body, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.sub)),
          const SizedBox(height: 18),
          Builder(builder: (c) => SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(c), child: const Text('확인했어요')))),
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
    DeviceService.instance.onArrived(null);
    m.removeListener(reschedule);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
            bottom: false,
            child: IndexedStack(index: index, children: [
              HomeScreen(onExit: widget.onExit, go: (i) => setState(() => index = i)),
              const BookScreen(),
              const AssetScreen(),
              const GoalScreen(),
            ])),
        bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => setState(() => index = i),
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            indicatorColor: AppColors.mist,
            destinations: [
              const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: '홈'),
              NavigationDestination(
                  icon: Badge(isLabelVisible: AppScope.of(context).pending.isNotEmpty, backgroundColor: AppColors.accent, child: const Icon(Icons.receipt_long_outlined)),
                  selectedIcon: const Icon(Icons.receipt_long), label: '가계부'),
              const NavigationDestination(icon: Icon(Icons.savings_outlined), selectedIcon: Icon(Icons.savings), label: '자산'),
              const NavigationDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag), label: '목표'),
            ]),
      );
}
