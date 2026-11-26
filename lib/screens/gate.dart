import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mm_app/data/app_model.dart';
import 'package:mm_app/data/demo.dart';
import 'package:mm_app/data/store.dart';
import 'package:mm_app/screens/onboarding.dart';
import 'package:mm_app/screens/shell.dart';
import 'package:mm_app/services/auth_service.dart';
import 'package:mm_app/services/device_service.dart';
import 'package:mm_app/theme/app_theme.dart';
import 'package:mm_app/ui/widgets.dart';

/// 로그인 상태에 따라 첫 화면을 고른다.
class Gate extends StatefulWidget {
  const Gate({super.key});
  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  AppModel? model;
  String? uid;

  void use(AppModel? m, String? id) {
    final old = model;
    model = m;
    uid = id;
    WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
  }

  @override
  void dispose() {
    model?.dispose();
    super.dispose();
  }

  Future<void> demo() async {
    final s = await demoStore(DateTime.now());
    if (mounted) setState(() => use(AppModel(s, demo: true), null));
  }

  @override
  Widget build(BuildContext context) {
    if (model?.demo ?? false) return Session(key: ValueKey('demo'), model: model!, onExit: () => setState(() => use(null, null)));
    if (Firebase.apps.isEmpty) return LoginScreen(onDemo: demo, canSignIn: false);
    return StreamBuilder<User?>(
        stream: AuthService.instance.authStateChanges(),
        builder: (_, s) {
          if (s.connectionState == ConnectionState.waiting) return _Splash();
          final user = s.data;
          if (user == null) {
            if (uid != null) {
              use(null, null);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
              });
              DeviceService.instance.clearAccount();
            }
            return LoginScreen(onDemo: demo);
          }
          if (uid != user.uid) {
            final store = FirestoreStore(user.uid);
            final next = AppModel(store);
            store.onLateError = next.reportError;
            use(next, user.uid);
          }
          return Session(key: ValueKey(user.uid), model: model!, onExit: () => AuthService.instance.signOut());
        });
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Logo()));
}

class Logo extends StatelessWidget {
  const Logo({super.key});
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Image(image: AssetImage('assets/images/pets/growing.png'), width: 132, excludeFromSemantics: true),
        SizedBox(height: 8),
        Text('Liqua', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800, letterSpacing: -1, color: AppColors.deep)),
        Text('돈 관리의 시작부터 미래의 설계까지', style: TextStyle(color: AppColors.sub, fontSize: 15)),
      ]);
}

class Session extends StatelessWidget {
  const Session({super.key, required this.model, required this.onExit});
  final AppModel model;
  final VoidCallback onExit;
  @override
  Widget build(BuildContext context) => AppScope(
      model: model,
      child: Builder(builder: (c) {
        final m = AppScope.of(c);
        if (m.error != null && !m.ready) return _LoadError(error: m.error!, onExit: onExit);
        if (!m.ready) return _Loading(onExit: onExit);
        return m.onboarded ? Shell(onExit: onExit) : Onboarding(onExit: onExit);
      }));
}

class _Loading extends StatefulWidget {
  const _Loading({required this.onExit});
  final VoidCallback onExit;
  @override
  State<_Loading> createState() => _LoadingState();
}

class _LoadingState extends State<_Loading> {
  var slow = false;
  late final Timer _t = Timer(Duration(seconds: 8), () => setState(() => slow = true));
  @override
  void initState() {
    super.initState();
    _t;
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: SafeArea(
          child: Column(children: [
        Expanded(child: HomeSkeleton()),
        if (slow) ...[
          Text('처음 불러올 때는 인터넷 연결이 필요해요'),
          TextButton(onPressed: widget.onExit, child: Text('나가기')),
          SizedBox(height: 16),
        ],
      ])));
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onExit});
  final Object error;
  final VoidCallback onExit;
  @override
  Widget build(BuildContext context) => Scaffold(
      body: SafeArea(
          child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('내 데이터를 불러오지 못했어요', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                SizedBox(height: 8),
                Text(saveError(error), textAlign: TextAlign.center, style: TextStyle(color: AppColors.sub)),
                SizedBox(height: 20),
                FilledButton(onPressed: onExit, child: Text('로그인 화면으로')),
              ]))));
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onDemo, this.canSignIn = true});
  final Future<void> Function() onDemo;
  final bool canSignIn;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  var busy = false;
  String? error, detail;
  var retry = false;

  Future<void> signIn() async {
    setState(() {
      busy = true;
      error = null;
      detail = null;
      retry = false;
    });
    try {
      await AuthService.instance.signInWithGoogle();
    } catch (e) {
      debugPrint('로그인 실패: $e');
      final s = e.toString().toLowerCase();
      retry = s.contains('network') || s.contains('timeout');
      error = retry ? '네트워크에 연결할 수 없어요' : '계정 정보를 확인하세요';
      detail = errorDetail(e);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: SafeArea(
          child: Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(children: [
                Expanded(child: Center(child: SingleChildScrollView(child: Logo()))),
                if (error != null)
                  Padding(padding: EdgeInsets.only(bottom: 12), child: Semantics(liveRegion: true, child: Column(children: [
                    Text(error!, style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
                    if (detail != null) Padding(padding: EdgeInsets.only(top: 4), child: SelectableText(detail!, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.sub))),
                  ]))),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                        onPressed: busy || !widget.canSignIn ? null : signIn,
                        child: Text(busy ? '로그인하는 중' : retry ? '다시 시도' : 'Google로 계속하기'))),
                SizedBox(height: 8),
                TextButton(onPressed: busy ? null : widget.onDemo, child: Text('로그인 없이 예시로 둘러보기')),
              ]))));
}
