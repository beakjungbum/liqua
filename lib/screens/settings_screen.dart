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
          if (m.demo)
            item(Icons.play_circle_outline, '결제 알림 시연', '4,500원 결제 알림이 온 것처럼 기록해요', () async {
              final t = m.now;
              final two = [t.month, t.day, t.hour, t.minute].map((v) => '$v'.padLeft(2, '0')).toList();
              await m.handleNotice('[KB국민카드] 4,500원 승인 스타벅스 ${two[0]}/${two[1]} ${two[2]}:${two[3]}', app: '문자', at: t);
              if (context.mounted) toast(context, '스타벅스 4,500원을 기록했어요. 오늘 남은 돈 ${won(m.todayLeft)}');
            }),
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
