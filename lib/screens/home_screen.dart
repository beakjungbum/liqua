import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mm_app/data/app_model.dart';
import 'package:mm_app/domain/budget.dart';
import 'package:mm_app/domain/money.dart';
import 'package:mm_app/screens/book_screen.dart';
import 'package:mm_app/screens/chat_screen.dart';
import 'package:mm_app/screens/settings_screen.dart';
import 'package:mm_app/theme/app_theme.dart';
import 'package:mm_app/ui/widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onExit, required this.go});
  final VoidCallback onExit;
  final void Function(int) go;

  @override
  Widget build(BuildContext context) {
    final m = AppScope.of(context);
    final cats = m.monthByCategory;
    final shares = percentShares([for (final c in cats) c.$2]);
    return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
      Row(children: [
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m.demo ? '내 자산 (예시 데이터)' : '내 자산', style: const TextStyle(color: AppColors.sub, fontWeight: FontWeight.w600)),
          Won(m.total, size: 32),
        ])),
        IconButton(tooltip: '설정', onPressed: () => push(context, SettingsScreen(onExit: onExit)), icon: const CircleAvatar(backgroundColor: AppColors.sage, child: Icon(Icons.person, color: AppColors.deep))),
      ]),
      const SizedBox(height: 12),
      TodayCard(onTap: () => push(context, const BudgetDetail())),
      SoftCard(
          onTap: () => go(3),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Expanded(child: Text('목표 달성률', style: TextStyle(fontWeight: FontWeight.w700))),
              Text('${percentText(m.percent)}%', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.deep)),
            ]),
            const SizedBox(height: 8),
            Bar(m.percent / 100),
            const SizedBox(height: 8),
            Between(Text('목표 ${won(m.target)}', style: const TextStyle(color: AppColors.sub, fontSize: 13)), Text(m.total >= m.target ? '달성했어요' : '${won(m.target - m.total)} 남음', textAlign: TextAlign.end, style: const TextStyle(color: AppColors.sub, fontSize: 13))),
          ])),
      if (m.pending.isNotEmpty)
        SoftCard(
            color: AppColors.accentSoft, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14), onTap: () => go(1),
            child: Text('확인이 필요한 결제 알림 ${m.pending.length}건', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700))),
      for (final f in m.fixed)
        if (daysBetween(m.today, f.nextDue(m.today)) <= 1)
          SoftCard(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(children: [
                const Icon(Icons.notifications_none, size: 20, color: AppColors.olive),
                const SizedBox(width: 10),
                Expanded(child: Text('${daysBetween(m.today, f.nextDue(m.today)) == 0 ? '오늘' : '내일'} ${f.name} 결제일')),
                Text(won(f.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
              ])),
      SoftCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('이번 달 소비', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        if (cats.isEmpty)
          const Empty('아직 이번 달 기록이 없어요')
        else
          Row(children: [
            Donut([for (final c in cats) c.$2], child: Column(mainAxisSize: MainAxisSize.min, children: [Won(m.monthTotal, size: 18), const Text('총 소비', style: TextStyle(fontSize: 12, color: AppColors.sub))])),
            const SizedBox(width: 20),
            Expanded(
                child: Column(children: [
              for (final (i, c) in cats.take(4).indexed)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.chart[i])),
                      const SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${c.$1.label} ${shares[i]}%', style: const TextStyle(fontSize: 13)),
                        Text(won(c.$2), style: const TextStyle(fontSize: 13, color: AppColors.sub)),
                      ])),
                    ])),
            ])),
          ]),
      ])),
      SoftCard(
          child: Column(children: [
        Section('최근 거래 내역', action: '전체 보기', onAction: () => go(1)),
        if (m.txns.isEmpty) const Empty('결제 알림을 켜면 여기에 쌓여요') else for (final t in m.txns.take(3)) TxnRow(t),
      ])),
      _says(context, m),
    ]);
  }

  Widget _says(BuildContext c, AppModel m) {
    if (m.sharpDrop) return MascotSays('자산이 하루 만에 ${won(m.previousSnapshot!.total - m.total)} 줄었어요', '자산 탭에서 바뀐 항목을 봐 주세요', worried: true, onTap: () => go(2));
    final a = m.advices;
    if (a.isNotEmpty) return MascotSays(a.first.title, a.first.evidence, onTap: () => push(c, const InsightScreen()));
    return MascotSays('${m.streakDays}일째 기록하고 있어요', m.stage.next);
  }
}

class TodayCard extends StatelessWidget {
  const TodayCard({super.key, this.onTap});
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final m = AppScope.of(context);
    final left = m.todayLeft;
    const soft = Color(0xFFF1F3E6);
    return SoftCard(
        color: m.over ? const Color(0xFF8F4322) : AppColors.olive,
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Between(
              Text(m.over ? '오늘 초과한 돈' : '오늘 쓸 수 있는 돈', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              m.todayCarry == 0
                  ? const SizedBox.shrink()
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
                      child: Text('이월 ${m.todayCarry > 0 ? '+' : ''}${won(m.todayCarry)}', style: const TextStyle(color: Colors.white, fontSize: 12)))),
          Won(left.abs(), size: 42, color: Colors.white),
          const SizedBox(height: 8),
          Bar(m.todayBudget <= 0 ? 1 : m.todaySpent / m.todayBudget, color: m.over ? const Color(0xFFFFB38A) : const Color(0xFFD9E0B8), track: Colors.black26),
          const SizedBox(height: 8),
          Between(Text('${won(m.todayBudget)} 중 ${won(m.todaySpent)} 사용', style: const TextStyle(color: soft, fontSize: 13)), Text(m.over ? m.tomorrowBudget > 0 ? '내일 ${won(m.tomorrowBudget)}' : '내일 쓸 돈 없음' : '${m.daysLeft}일 남음', textAlign: TextAlign.end, style: const TextStyle(color: soft, fontSize: 13))),
        ]));
  }
}

class BudgetDetail extends StatelessWidget {
  const BudgetDetail({super.key});
  @override
  Widget build(BuildContext context) {
    final m = AppScope.of(context);
    final p = m.plan!;
    Widget row(String a, String b, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [Expanded(child: Text(a)), Text(b, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600))]));
    return Scaffold(
        appBar: AppBar(title: const Text('하루 생활비')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const TodayCard(),
          SoftCard(
              child: Column(children: [
            row('생활비', won(p.living)),
            row('고정 지출', '− ${won(p.fixed)}'),
            row('먼저 저축', '− ${won(p.saving)}'),
            const Divider(),
            row('쓸 수 있는 돈', won(p.pool)),
            row('기간', '${DateFormat('M/d').format(p.start)}부터 ${p.days}일'),
            row('하루 기본', won(p.base(m.today)), bold: true),
            row('이월', won(m.todayCarry)),
            row('오늘 사용 가능', won(m.todayBudget), bold: true),
          ])),
          if (m.todayLeft > 0) ...[
            const Text('오늘 남은 돈은 그대로 두면 내일로 넘어가요.', style: TextStyle(color: AppColors.sub)),
            const SizedBox(height: 10),
            SaveButton('${won(m.todayLeft)} 목표 저축으로 보내기', () async {
              await attempt(context, () async {
                final v = await m.sendLeftoverToSaving(m.todayLeft);
                if (context.mounted) toast(context, '${won(v)}을 저축으로 기록했어요. 실제 이체는 은행 앱에서 해 주세요.');
              });
            }),
          ],
        ]));
  }
}

class InsightScreen extends StatefulWidget {
  const InsightScreen({super.key});
  @override
  State<InsightScreen> createState() => _InsightScreenState();
}

class _InsightScreenState extends State<InsightScreen> {
  String? text;
  @override
  Widget build(BuildContext context) {
    final m = AppScope.of(context);
    final cats = m.monthByCategory, shares = percentShares([for (final c in cats) c.$2]);
    final advice = m.advices;
    return Scaffold(
        appBar: AppBar(title: const Text('소비 분석')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          SoftCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('이번 달 지출', style: TextStyle(fontWeight: FontWeight.w700)),
            Won(m.monthTotal),
            const SizedBox(height: 10),
            for (final (i, c) in cats.indexed)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Column(children: [
                    Between(Text(c.$1.label), Text('${won(c.$2)}  ${shares[i]}%', style: const TextStyle(fontWeight: FontWeight.w600))),
                    const SizedBox(height: 5),
                    Bar(shares[i] / 100, height: 7),
                  ])),
          ])),
          if (advice.isEmpty)
            MascotSays('기록이 30건 모이면 제안을 드려요', '지금 ${m.expenses.length}건이에요')
          else ...[
            for (final a in advice)
              SoftCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                Text(a.evidence, style: const TextStyle(color: AppColors.sub, height: 1.45)),
              ])),
            if (text != null) Bubble2(text!),
            SaveButton('AI에게 실천 방법 듣기', () async {
              final t = await ai.explain(advice);
              if (mounted) setState(() => text = t ?? '지금은 AI에 연결할 수 없어요. 위 수치는 앱이 직접 계산한 값이에요.');
            }),
            const SizedBox(height: 8),
            const Text('수치는 앱이 계산하고 AI는 설명만 해요. 이름과 결제 원문은 보내지 않아요.', style: TextStyle(fontSize: 12, color: AppColors.sub)),
          ],
        ]));
  }
}

class Bubble2 extends StatelessWidget {
  const Bubble2(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => SoftCard(color: AppColors.mist, child: SelectableText(text, style: const TextStyle(height: 1.5)));
}
