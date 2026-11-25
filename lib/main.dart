import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mm_app/firebase_options.dart';
import 'package:mm_app/screens/gate.dart';
import 'package:mm_app/services/auth_service.dart';
import 'package:mm_app/services/device_service.dart';
import 'package:mm_app/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (e) {
    // 초기화에 실패해도 둘러보기는 쓸 수 있다.
    debugPrint('Firebase 초기화 실패: $e');
  }
  // App Check 가 실패해도 로그인과 저장은 이어 간다.
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode ? AndroidDebugProvider() : AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode ? AppleDebugProvider() : AppleDeviceCheckProvider(),
      providerWeb: kDebugMode ? WebDebugProvider() : null,
    );
  } catch (e) {
    debugPrint('App Check 초기화 실패: $e');
  }
  if (Firebase.apps.isNotEmpty) AuthService.instance.listenToAuthState();
  try {
    await DeviceService.instance.init();
  } catch (e) {
    debugPrint('알림 초기화 실패: $e');
  }
  runApp(LiquaApp());
}

class LiquaApp extends StatefulWidget {
  const LiquaApp({super.key, this.home = const Gate()});
  final Widget home;
  @override
  State<LiquaApp> createState() => _LiquaAppState();
}

class _LiquaAppState extends State<LiquaApp> with WidgetsBindingObserver {
  void _read() => AppColors.dark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _read();
  }

  /// 색을 위젯 트리 밖에서 읽으므로 밝기가 바뀌면 전부 다시 그린다.
  @override
  void didChangePlatformBrightness() {
    setState(_read);
    void again(Element e) {
      e.markNeedsBuild();
      e.visitChildren(again);
    }

    (context as Element).visitChildren(again);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Liqua',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.current,
        themeAnimationDuration: Duration.zero,
        locale: const Locale('ko', 'KR'),
        supportedLocales: const [Locale('ko', 'KR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: widget.home,
      );
}
