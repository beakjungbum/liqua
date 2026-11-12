import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mm_app/screens/login_screen.dart';
import 'package:mm_app/services/auth_service.dart';
import 'package:mm_app/theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  Future<void> logout(BuildContext context) async {
    await AuthService.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }
  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '계정 없음';
    return Scaffold(
      appBar: AppBar(backgroundColor: AppColors.background, title: const Text('설정')),
      body: SafeArea(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          child: Text('로그인 계정: $email',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        const Spacer(),
        ElevatedButton(onPressed: () => logout(context), child: const Text('로그아웃')),
        ]),
      )),
    );
  }
}