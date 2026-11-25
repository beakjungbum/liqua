import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:mm_app/firebase_options.dart';
import 'package:mm_app/theme/app_theme.dart';
import 'package:mm_app/screens/splash_screen.dart';
import 'package:mm_app/services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Firebase 초기화
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    debugPrint('Firebase 초기화 성공');
  } catch (e, stackTrace) {
    debugPrint('Firebase 초기화 실패: $e');
    debugPrintStack(stackTrace: stackTrace);
    runApp(const FirebaseInitializationErrorApp());
    return;
  }

  // 2. App Check 초기화
  // 기존 프로젝트에서 사용하던 Provider 설정을 유지합니다.
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleDeviceCheckProvider(),
      providerWeb: kDebugMode ? WebDebugProvider() : null,
    );

    debugPrint('App Check 초기화 성공');
  } catch (e, stackTrace) {
    debugPrint('App Check 초기화 실패: $e');
    debugPrintStack(stackTrace: stackTrace);
  }

  // 3. Firebase 초기화 완료 후 인증 상태 구독
  AuthService.instance.listenToAuthState();

  // 4. 앱 실행
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}

class FirebaseInitializationErrorApp extends StatelessWidget {
  const FirebaseInitializationErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Firebase 초기화에 실패했습니다.\n\n'
              'firebase_options.dart 설정과\n'
              '터미널의 오류 메시지를 확인한 후\n'
              '앱을 완전히 종료하고 다시 실행하세요.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}