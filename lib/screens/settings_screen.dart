import 'package:flutter/material.dart';
import 'package:mm_app/domain/money.dart';
import 'package:mm_app/screens/book_screen.dart';
import 'package:mm_app/screens/onboarding.dart';
import 'package:mm_app/theme/app_theme.dart';
import 'package:mm_app/ui/widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.onExit});
  final VoidCallback onExit;
  @override
  Widget build(BuildContext context) {
    final m = AppScope.of(context);
    final p = m.profile;
    Widget item(IconData i, String t, String s, VoidCallback f) => ListTile(leading: Icon(i, color: AppColors.olive), title: Text(t), subtitle: Text(s, style: const TextStyle(color: AppColors.sub)), trailing: const Icon(Icons.chevron_right), contentPadding: EdgeInsets.zero, onTap: f);
    return Scaffold(
        appBar: AppBar(title: const Text('설정')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text(m.demo ? '예시 데이터로 둘러보는 중이에요. 바꾼 내용은 저장되지 않아요.' : '${m.name.isEmpty ? '내' : '${m.name}님의'} 계정', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          item(Icons.account_balance_wallet_outlined, '생활비 설정', '하루 기본 ${won(m.plan?.base(m.today) ?? 0)}', () => push(context, const PlanScreen())),
          item(Icons.event_repeat_outlined, '고정지출', '${m.fixed.length}개', () => push(context, const FixedScreen())),
          item(Icons.chat_outlined, '인터뷰 다시 하기', '만 ${p.age}세 · ${p.region} · 위험 ${p.risk}', () => push(context, const InterviewScreen())),
          const SizedBox(height: 20),
          FilledButton(
              onPressed: () {
                Navigator.of(context).popUntil((r) => r.isFirst);
                onExit();
              },
              child: Text(m.demo ? '둘러보기 끝내기' : '로그아웃')),
        ]));
  }
}
