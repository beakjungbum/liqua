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
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode ? const AndroidDebugProvider() : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode ? const AppleDebugProvider() : const AppleDeviceCheckProvider(),
      providerWeb: kDebugMode ? WebDebugProvider() : null,
    );
    AuthService.instance.listenToAuthState();
  } catch (e) {
    // 초기화에 실패해도 둘러보기는 쓸 수 있다.
    debugPrint('Firebase 초기화 실패: $e');
  }
  try {
    await DeviceService.instance.init();
  } catch (e) {
    debugPrint('알림 초기화 실패: $e');
  }
  runApp(const LiquaApp());
}

class LiquaApp extends StatelessWidget {
  const LiquaApp({super.key, this.home = const Gate()});
  final Widget home;
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Liqua',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: const Locale('ko', 'KR'),
        supportedLocales: const [Locale('ko', 'KR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: home,
      );
}
