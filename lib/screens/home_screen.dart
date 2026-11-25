import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mm_app/data/app_model.dart';
import 'package:mm_app/domain/budget.dart';
import 'package:mm_app/domain/money.dart';
import 'package:mm_app/screens/book_screen.dart';
import 'package:mm_app/screens/chat_screen.dart';
import 'package:mm_app/screens/settings_screen.dart';
import 'package:mm_app/services/device_service.dart';
import 'package:mm_app/theme/app_theme.dart';
import 'package:mm_app/ui/widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onExit, required this.go, this.scroll});
  final ScrollController? scroll;
  final VoidCallback onExit;
  final void Function(int) go;

  @override
  Widget build(BuildContext context) {
    final m = AppScope.of(context);
    final cats = m.monthByCategory;
    final shares = percentShares([for (final c in cats) c.$2]);
    final todo = [
      if (m.pending.isNotEmpty) TodoRow(Icons.mark_email_unread_rounded, '확인이 필요한 결제', '${m.pending.length}건', strong: true, onTap: () => go(1)),
      for (final f in m.fixed)
        if (daysBetween(m.today, f.nextDue(m.today)) <= 1)
          TodoRow(Icons.notifications_none_rounded, '${daysBetween(m.today, f.nextDue(m.today)) == 0 ? '오늘' : '내일'} ${f.name}', won(f.amount), onTap: () => push(context, FixedScreen())),
    ];
    return RefreshPage(
        also: () => m.demo ? Future<void>.value() : DeviceService.instance.drain(m),
        child: ListView(controller: scroll, physics: AlwaysScrollableScrollPhysics(), padding: EdgeInsets.fromLTRB(20, 8, 20, 96), children: [
      Row(children: [
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m.demo ? '내 자산 (예시 데이터)' : '내 자산', style: TextStyle(color: AppColors.sub, fontWeight: FontWeight.w600)),
          Won(m.total, size: 32),
        ])),
        IconButton(tooltip: '설정', onPressed: () => push(context, SettingsScreen(onExit: onExit)), icon: CircleAvatar(backgroundColor: AppColors.sage, child: Icon(Icons.person_rounded, color: AppColors.ink))),
      ]),
      SizedBox(height: 12),
      TodayCard(onTap: () => push(context, BudgetDetail())),
      SoftCard(
          onTap: () => go(3),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: Text('목표 달성률', style: TextStyle(fontWeight: FontWeight.w700))),
              Text('${percentText(m.percent)}%', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.deep)),
            ]),
            SizedBox(height: 8),
            Bar(m.percent / 100),
            SizedBox(height: 8),
            Between(Text('목표 ${won(m.target)}', style: TextStyle(color: AppColors.sub, fontSize: 13)), Text(m.total >= m.target ? '달성했어요' : '${won(m.target - m.total)} 남음', textAlign: TextAlign.end, style: TextStyle(color: AppColors.sub, fontSize: 13))),
          ])),
      if (todo.isNotEmpty)
        SoftCard(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ...todo.take(3),
              if (todo.length > 3) Padding(padding: EdgeInsets.only(bottom: 12), child: Text('${todo.length - 3}개 더 있어요', style: TextStyle(color: AppColors.sub, fontSize: 13))),
            ])),
      // 위는 오늘 할 일, 아래는 지난 소비. 묶음 사이를 더 띄운다(근접성).
      SizedBox(height: 12),
      SoftCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('이번 달 소비', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        SizedBox(height: 16),
        if (cats.isEmpty)
          Empty('아직 이번 달 기록이 없어요')
        else
          Row(children: [
            Donut([for (final c in cats) c.$2], child: Column(mainAxisSize: MainAxisSize.min, children: [Won(m.monthTotal, size: 18), Text('총 소비', style: TextStyle(fontSize: 12, color: AppColors.sub))])),
            SizedBox(width: 20),
            Expanded(
                child: Column(children: [
              for (final (i, c) in cats.take(4).indexed)
                Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.chart[i])),
                      SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${c.$1.label} ${shares[i]}%', style: TextStyle(fontSize: 13)),
                        Text(won(c.$2), style: TextStyle(fontSize: 13, color: AppColors.sub)),
                      ])),
                    ])),
            ])),
          ]),
      ])),
      SoftCard(
          child: Column(children: [
        Section('최근 거래 내역', action: '전체 보기', onAction: () => go(1)),
        if (m.txns.isEmpty) Empty('결제 알림을 켜면 여기에 쌓여요') else for (final t in m.txns.take(3)) TxnRow(t),
      ])),
      _says(context, m),
    ]));
  }

  Widget _says(BuildContext c, AppModel m) {
    if (m.sharpDrop) return MascotSays('자산이 하루 만에 ${won(m.previousSnapshot!.total - m.total)} 줄었어요', '자산 탭에서 바뀐 항목을 봐 주세요', worried: true, onTap: () => go(2));
    final a = m.advices;
    if (a.isNotEmpty) return MascotSays(a.first.title, a.first.evidence, onTap: () => push(c, InsightScreen()));
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
    const soft = AppColors.ink;
    return SoftCard(
        color: m.over ? AppColors.peach : AppColors.main,
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Between(
              Text(m.over ? '오늘 초과한 돈' : '오늘 쓸 수 있는 돈', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700)),
              m.todayCarry == 0
                  ? SizedBox.shrink()
                  : Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white54, borderRadius: BorderRadius.circular(20)),
                      child: Text('이월 ${m.todayCarry > 0 ? '+' : ''}${won(m.todayCarry)}', style: TextStyle(color: AppColors.ink, fontSize: 12)))),
          Won(left.abs(), size: 42, color: AppColors.ink),
          SizedBox(height: 8),
          Bar(m.todayBudget <= 0 ? 1 : m.todaySpent / m.todayBudget, color: m.over ? AppColors.orange : Color(0xFF5F6545), track: Colors.white54),
          SizedBox(height: 8),
          Between(Text('${won(m.todayBudget)} 중 ${won(m.todaySpent)} 사용', style: TextStyle(color: soft, fontSize: 13)), Text(m.over ? m.tomorrowBudget > 0 ? '내일 ${won(m.tomorrowBudget)}' : '내일 쓸 돈 없음' : '${m.daysLeft}일 남음', textAlign: TextAlign.end, style: TextStyle(color: soft, fontSize: 13))),
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
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [Expanded(child: Text(a)), Text(b, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600))]));
    return Scaffold(
        appBar: AppBar(title: Text('하루 생활비')),
        body: ListView(padding: pagePad(context), children: [
          TodayCard(),
          SoftCard(
              child: Column(children: [
            row('생활비', won(p.living)),
            row('고정 지출', '− ${won(p.fixed)}'),
            row('먼저 저축', '− ${won(p.saving)}'),
            Divider(),
            row('쓸 수 있는 돈', won(p.pool)),
            row('기간', '${DateFormat('M/d').format(p.start)}부터 ${p.days}일'),
            row('하루 기본', won(p.base(m.today)), bold: true),
            row('이월', won(m.todayCarry)),
            row('오늘 사용 가능', won(m.todayBudget), bold: true),
          ])),
          if (m.todayLeft > 0) ...[
            Text('오늘 남은 돈은 그대로 두면 내일로 넘어가요.', style: TextStyle(color: AppColors.sub)),
            SizedBox(height: 8),
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
        appBar: AppBar(title: Text('소비 분석')),
        body: ListView(padding: pagePad(context), children: [
          SoftCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('이번 달 지출', style: TextStyle(fontWeight: FontWeight.w700)),
            Won(m.monthTotal),
            SizedBox(height: 8),
            for (final (i, c) in cats.indexed)
              Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Column(children: [
                    Between(Text(c.$1.label), Text('${won(c.$2)}  ${shares[i]}%', style: TextStyle(fontWeight: FontWeight.w600))),
                    SizedBox(height: 4),
                    Bar(shares[i] / 100, height: 7),
                  ])),
          ])),
          if (advice.isEmpty)
            MascotSays('기록이 30건 모이면 제안을 드려요', '지금 ${m.expenses.length}건이에요')
          else ...[
            for (final a in advice)
              SoftCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                SizedBox(height: 4),
                Text(a.evidence, style: TextStyle(color: AppColors.sub, height: 1.45)),
              ])),
            if (text != null) Bubble2(text!),
            SaveButton('AI에게 실천 방법 듣기', () async {
              final t = await ai.explain(advice);
              if (mounted) setState(() => text = t ?? '지금은 AI에 연결할 수 없어요. 위 수치는 앱이 직접 계산한 값이에요.');
            }),
            SizedBox(height: 8),
            Text('수치는 앱이 계산하고 AI는 설명만 해요. 이름과 결제 원문은 보내지 않아요.', style: TextStyle(fontSize: 12, color: AppColors.sub)),
          ],
        ]));
  }
}

class Bubble2 extends StatelessWidget {
  const Bubble2(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => SoftCard(color: AppColors.mist, child: SelectableText(text, style: TextStyle(height: 1.5)));
}
