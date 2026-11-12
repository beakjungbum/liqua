import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mm_app/screens/splash_screen.dart';
import 'package:mm_app/theme/app_theme.dart';
import 'package:mm_app/services/auth_service.dart';
//
//
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('Firebase 초기화에 실패했습니다. README의 FlutterFire CLI 설정을 확인하세요.\n$e');
  }
  if (Firebase.apps.isNotEmpty) {
    AuthService.instance.listenToAuthState();
  }
  runApp(const MainApp());
}
class MainApp extends StatelessWidget {
  const MainApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp( 
      debugShowCheckedModeBanner: false,
      // 앱 전체에 테마를 붙인다
      theme: AppTheme.light,
      // 켜자마자 스플래시
      home: const SplashScreen(),
    );
  }
}
