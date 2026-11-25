import 'package:flutter/material.dart';
import 'package:mm_app/domain/growth.dart';
import 'package:mm_app/domain/money.dart';
import 'package:mm_app/screens/chat_screen.dart';
import 'package:mm_app/screens/onboarding.dart';
import 'package:mm_app/theme/app_theme.dart';
import 'package:mm_app/ui/widgets.dart';

class GoalScreen extends StatefulWidget {
  const GoalScreen({super.key});
  @override
  State<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends State<GoalScreen> {
  var rate = 3.0;
  @override
  Widget build(BuildContext context) {
    final m = AppScope.of(context);
    final months = monthsToGoal(current: m.total, goal: m.target, monthly: m.monthlySaving, annualRate: rate);
    final when = months == null ? null : DateTime(m.today.year, m.today.month + months);
    return ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 28), children: [
      const Text('나의 목표', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      const SizedBox(height: 14),
      SoftCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('내가 모으고 싶은 금액${m.profile.goalReason == null ? '' : ' · ${m.profile.goalReason}'}', style: const TextStyle(color: AppColors.sub)),
        Won(m.target, size: 34),
        const SizedBox(height: 8),
        Bar(m.percent / 100),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Text('모은 금액 ${won(m.total)}', style: const TextStyle(fontWeight: FontWeight.w700))),
          Text('${percentText(m.percent)}%', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.olive)),
        ]),
      ])),
      FilledButton(onPressed: () => sheet<void>(context, const _TargetForm()), child: const Text('목표 수정하기')),
      const SizedBox(height: 12),
      SoftCard(
          color: AppColors.mist,
          child: Column(children: [
            Row(children: [
              Expanded(child: Text('${m.stage.label} 단계', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              Text('Lv.${m.level}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.deep)),
            ]),
            const SizedBox(height: 6),
            Mascot(stage: m.stage, size: 150, percent: m.percent, crowns: m.completedGoals, worried: m.over),
            const SizedBox(height: 10),
            Row(children: [
              for (final s in PetStage.values.skip(1))
                Expanded(
                    child: Column(children: [
                  Container(width: s == m.stage ? 16 : 11, height: s == m.stage ? 16 : 11, decoration: BoxDecoration(shape: BoxShape.circle, color: s == m.stage ? AppColors.accent : s.index < m.stage.index ? AppColors.olive : Colors.white)),
                  const SizedBox(height: 5),
                  Text(s.label, style: TextStyle(fontSize: 12, fontWeight: s == m.stage ? FontWeight.w800 : FontWeight.w500, color: s == m.stage ? AppColors.text : AppColors.sub)),
                ])),
            ]),
            const SizedBox(height: 12),
            Text(m.stage.next, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Bar((m.xp - xpForLevel(m.level)) / (xpForLevel(m.level + 1) - xpForLevel(m.level)), height: 7, track: Colors.white),
            const SizedBox(height: 5),
            Text('경험치 ${m.xp} / ${xpForLevel(m.level + 1)} · ${m.streakDays}일 연속 기록', style: const TextStyle(fontSize: 12, color: AppColors.sub)),
          ])),
      SoftCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('지금 속도로 모으면', style: TextStyle(color: AppColors.sub)),
        Text(months == 0 ? '이미 달성했어요' : when == null ? '저축액을 정하면 예상일을 보여 드려요' : '${when.year}년 ${when.month}월쯤 달성', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        Text('월 ${won(m.monthlySaving)} 저축, 연 ${rate.toStringAsFixed(1)}% 복리로 계산한 값이에요. 실제 수익을 보장하지 않아요.', style: const TextStyle(fontSize: 12, color: AppColors.sub, height: 1.4)),
        Slider(value: rate, max: 10, divisions: 20, label: '연 ${rate.toStringAsFixed(1)}%', activeColor: AppColors.olive, inactiveColor: AppColors.mist, onChanged: (v) => setState(() => rate = v)),
      ])),
      SoftCard(
          onTap: () => push(context, const ChatScreen()),
          child: Column(children: [
            Section('AI 상담', action: '챗봇과 더 대화하기', onAction: () => push(context, const ChatScreen())),
            const Align(alignment: Alignment.centerLeft, child: Bubble('궁금한 게 있으면 언제든 물어봐!')),
          ])),
      SoftCard(
          onTap: () => push(context, const GuideScreen()),
          child: const Row(children: [
            IconTile(Icons.card_giftcard),
            SizedBox(width: 12),
            Expanded(child: Text('받을 수 있는 지원 혜택과 투자 정보', style: TextStyle(fontWeight: FontWeight.w700))),
            Icon(Icons.chevron_right, color: AppColors.sub),
          ])),
    ]);
  }
}

class _TargetForm extends StatefulWidget {
  const _TargetForm();
  @override
  State<_TargetForm> createState() => _TargetFormState();
}

class _TargetFormState extends State<_TargetForm> {
  final form = GlobalKey<FormState>();
  late final c = TextEditingController(text: comma(AppScope.read(context).target));
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
      key: form,
      child: Column(children: [
        MoneyField(c, '목표 금액', autofocus: true),
        SaveButton('저장', () async {
          if (!form.currentState!.validate()) return;
          final ok = await attempt(context, () => AppScope.read(context).setTarget(parseWon(c.text)!));
          if (ok && context.mounted) Navigator.pop(context);
        }),
      ]));
}
