import 'package:flutter/material.dart';
//import 'package:mm_app/screens/home_screen.dart';
import 'package:mm_app/screens/shell_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mm_app/services/auth_service.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: 0.72,
                    // 색은 app_theme의 elevatedButtonTheme에서
                    child: Image.asset('assets/images/sku_logo.png', height: 70),
                ),
              ),
            const SizedBox(width: 1),
            const Text('Liqua',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
            ],
          ),
          ElevatedButton(
          onPressed: () async {
          try {
            await AuthService.instance.signInWithGoogle();
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Google 로그인에 실패했습니다.\n$e')),
            );
            return;
          }
  if (!context.mounted) return;
  if (FirebaseAuth.instance.currentUser == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('로그인이 취소되었습니다.')),
    );
    return;
  }
            Navigator.pushReplacement(
              context, 
              MaterialPageRoute(
                builder: (_) => const ShellScreen(),
                ),
              );
          },
          
          child: const Text('Google로 계속하기'), 
          ),
        ],
      ),
    ),
    );
  }
}