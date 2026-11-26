import 'package:flutter/material.dart';
import 'package:mm_app/domain/growth.dart';
import 'package:mm_app/domain/money.dart';
import 'package:mm_app/screens/chat_screen.dart';
import 'package:mm_app/screens/onboarding.dart';
import 'package:mm_app/theme/app_theme.dart';
import 'package:mm_app/ui/widgets.dart';

class GoalScreen extends StatefulWidget {
  const GoalScreen({super.key, this.scroll});
  final ScrollController? scroll;
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
    return RefreshPage(child: ListView(controller: widget.scroll, physics: AlwaysScrollableScrollPhysics(), padding: EdgeInsets.fromLTRB(20, 16, 20, 96), children: [
      Text('나의 목표', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      SizedBox(height: 16),
      SoftCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('내가 모으고 싶은 금액${m.profile.goalReason == null ? '' : ' · ${m.profile.goalReason}'}', style: TextStyle(color: AppColors.sub)),
        Won(m.target, size: 34),
        SizedBox(height: 8),
        Bar(m.percent / 100),
        SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text('모은 금액 ${won(m.total)}', style: TextStyle(fontWeight: FontWeight.w700))),
          Text('${percentText(m.percent)}%', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.text)),
        ]),
      ])),
      FilledButton(style: tonal(), onPressed: () => sheet<void>(context, TargetForm()), child: Text('목표 수정하기')),
      SizedBox(height: 12),
      SoftCard(
          color: AppColors.mist,
          child: Column(children: [
            Row(children: [
              Expanded(child: Text(petTitle(m.stage, m.completedGoals), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              Text('Lv.${m.level}', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.text)),
            ]),
            SizedBox(height: 8),
            Mascot(stage: m.stage, size: 150, percent: m.percent, crowns: m.completedGoals, worried: m.over),
            SizedBox(height: 8),
            Row(children: [
              for (final s in PetStage.values.skip(1))
                Expanded(child: _Step(image: petImage(s, crowns: m.completedGoals), label: s.label, reached: s.index <= m.stage.index, current: s == m.stage)),
            ]),
            if (m.stage == PetStage.crown) ...[
              SizedBox(height: 16),
              Align(alignment: Alignment.centerLeft, child: Text('왕관 랭크', style: TextStyle(fontWeight: FontWeight.w800))),
              SizedBox(height: 8),
              Row(children: [
                for (final r in CrownRank.values)
                  Expanded(
                      child: _Step(
                          image: crownImage(r),
                          label: r.label.replaceFirst(' 크라운', ''),
                          reached: r.index <= crownRank(m.completedGoals).index,
                          current: r == crownRank(m.completedGoals))),
              ]),
            ],
            SizedBox(height: 12),
            Text(petNext(m.stage, m.completedGoals), textAlign: TextAlign.center),
            SizedBox(height: 8),
            Bar((m.xp - xpForLevel(m.level)) / (xpForLevel(m.level + 1) - xpForLevel(m.level)), height: 7, track: AppColors.card),
            SizedBox(height: 4),
            Text('경험치 ${m.xp} / ${xpForLevel(m.level + 1)} · ${m.streakDays}일 연속 기록', style: TextStyle(fontSize: 12, color: AppColors.sub)),
          ])),
      SoftCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('지금 속도로 모으면', style: TextStyle(color: AppColors.sub)),
        Text(months == 0 ? '이미 달성했어요' : when == null ? '저축액을 정하면 예상일을 보여 드려요' : '${when.year}년 ${when.month}월쯤 달성', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        Text('월 ${won(m.monthlySaving)} 저축, 연 ${rate.toStringAsFixed(1)}% 복리로 계산한 값이에요. 실제 수익을 보장하지 않아요.', style: TextStyle(fontSize: 12, color: AppColors.sub, height: 1.4)),
        Slider(value: rate, max: 10, divisions: 20, label: '연 ${rate.toStringAsFixed(1)}%', activeColor: AppColors.orange, inactiveColor: AppColors.mist, onChanged: (v) => setState(() => rate = v)),
      ])),
      SoftCard(
          onTap: () => push(context, ChatScreen()),
          child: Column(children: [
            Section('AI 상담', action: '챗봇과 더 대화하기', onAction: () => push(context, ChatScreen())),
            Align(alignment: Alignment.centerLeft, child: Bubble('궁금한 게 있으면 언제든 물어봐!')),
          ])),
      SoftCard(
          onTap: () => push(context, GuideScreen()),
          child: Row(children: [
            IconTile(Icons.card_giftcard_rounded),
            SizedBox(width: 12),
            Expanded(child: Text('받을 수 있는 지원 혜택과 투자 정보', style: TextStyle(fontWeight: FontWeight.w700))),
            Icon(Icons.chevron_right_rounded, color: AppColors.sub),
          ])),
    ]));
  }
}

class TargetForm extends StatefulWidget {
  const TargetForm({super.key});
  @override
  State<TargetForm> createState() => _TargetFormState();
}

class _TargetFormState extends State<TargetForm> {
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
          if (ok && context.mounted) closeThis(context);
        }),
      ]));
}

/// 단계 미리보기 한 칸. 아직 못 간 칸은 흑백.
class _Step extends StatelessWidget {
  const _Step({required this.image, required this.label, required this.reached, required this.current});
  final String image, label;
  final bool reached, current;

  @override
  Widget build(BuildContext context) => Column(children: [
        Opacity(
            opacity: reached ? 1 : .35,
            child: ColorFiltered(
                colorFilter: reached ? ColorFilter.mode(Colors.transparent, BlendMode.dst) : ColorFilter.matrix([.33, .33, .33, 0, 0, .33, .33, .33, 0, 0, .33, .33, .33, 0, 0, 0, 0, 0, 1, 0]),
                child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: current ? AppColors.orange : Colors.transparent, width: 2)),
                    child: Image.asset(image, width: 36, height: 36, excludeFromSemantics: true)))),
        SizedBox(height: 4),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: current ? FontWeight.w800 : FontWeight.w500, color: current ? AppColors.text : AppColors.sub)),
      ]);
}
