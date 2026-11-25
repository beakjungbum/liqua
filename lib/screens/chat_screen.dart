import 'package:flutter/material.dart';
import 'package:mm_app/domain/rag.dart';
import 'package:mm_app/screens/onboarding.dart';
import 'package:mm_app/services/ai_service.dart';
import 'package:mm_app/theme/app_theme.dart';
import 'package:mm_app/ui/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

final ai = AiService();

class SourceLink extends StatelessWidget {
  const SourceLink(this.k, {super.key});
  final Knowledge k;
  @override
  Widget build(BuildContext context) => TextButton.icon(
      style: TextButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 4), alignment: Alignment.centerLeft),
      onPressed: () async {
        final ok = await launchUrl(Uri.parse(k.url), mode: LaunchMode.externalApplication).catchError((_) => false);
        if (!ok && context.mounted) toast(context, '링크를 열지 못했어요');
      },
      icon: Icon(Icons.open_in_new_rounded, size: 15),
      label: Text('출처: ${k.source} · ${k.checkedAt} 확인', style: TextStyle(fontSize: 12)));
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  final log = <(String, AiAnswer?)>[];
  var busy = false;

  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> send(String raw) async {
    final q = raw.trim();
    if (q.isEmpty || busy) return;
    final m = AppScope.read(context);
    setState(() {
      busy = true;
      log.add((q, null));
      input.clear();
    });
    final a = await ai.ask(q, m);
    if (!mounted) return;
    setState(() {
      busy = false;
      log.add(('', a));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text('AI 상담')),
      body: SafeArea(
          child: Column(children: [
        Expanded(
            child: ListView(controller: scroll, padding: EdgeInsets.all(20), children: [
          Bubble('공식 자료를 찾아 출처와 함께 답해요. 특정 종목을 사라고 권하지 않아요.'),
          for (final (q, a) in log)
            if (a == null)
              Bubble(q, me: true)
            else
              Bubble(a.text,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (a.notice != null) Padding(padding: EdgeInsets.only(top: 8), child: Text(a.notice!, style: TextStyle(fontSize: 12, color: AppColors.sub))),
                    for (final k in a.sources) SourceLink(k),
                  ])),
          if (busy) Bubble('자료를 찾고 있어요', child: Padding(padding: EdgeInsets.only(top: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Skeleton(width: 200, height: 12), SizedBox(height: 8), Skeleton(width: 140, height: 12)]))),
        ])),
        SizedBox(
            height: 48,
            child: ListView(scrollDirection: Axis.horizontal, padding: EdgeInsets.symmetric(horizontal: 20), children: [
              for (final h in ['예금자보호가 뭐야?', '이번 달 지출 어때?', 'ETF는 어떤 상품이야?', '오늘 생활비 얼마 남았어?']) Padding(padding: EdgeInsets.only(right: 8), child: ActionChip(label: Text(h), onPressed: busy ? null : () => send(h)))
            ])),
        Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 12, 4),
            child: Row(children: [
              Expanded(child: TextField(controller: input, maxLength: 300, onSubmitted: send, textInputAction: TextInputAction.send, decoration: InputDecoration(hintText: '무엇이든 물어보세요', counterText: ''))),
              IconButton(tooltip: '보내기', onPressed: busy ? null : () => send(input.text), icon: Icon(Icons.arrow_upward_rounded, color: AppColors.olive)),
            ])),
        Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 12), child: Text('내 소비를 물으면 합계 숫자만 AI에 보내요. 이름, 메모, 결제 원문은 보내지 않아요.', style: TextStyle(fontSize: 12, color: AppColors.sub))),
      ])));
}

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).profile;
    return DefaultTabController(
        length: 2,
        child: Scaffold(
            appBar: AppBar(title: Text('혜택과 투자 정보'), bottom: TabBar(labelColor: AppColors.text, indicatorColor: AppColors.orange, tabs: [Tab(text: '지원 혜택'), Tab(text: '투자 정보')])),
            body: FutureBuilder<List<Knowledge>>(
                future: ai.knowledge(),
                builder: (_, s) {
                  if (s.hasError) return Empty('자료를 불러오지 못했어요');
                  if (!s.hasData) return ListView(padding: EdgeInsets.all(20), children: [for (var i = 0; i < 3; i++) Padding(padding: EdgeInsets.only(bottom: 12), child: Skeleton(height: 168, radius: 22))]);
                  return TabBarView(children: [
                    _List(eligible(s.data!, age: p.age, monthlyIncome: p.monthlyIncome, region: p.region), '만 ${p.age}세, ${p.region} 기준이에요. 나머지 자격은 출처에서 확인해 주세요.'),
                    _List(investFor(s.data!, p.risk), '위험 성향 ${p.risk}에 맞춰 골랐어요. 매수 권유가 아니라 정보예요.'),
                  ]);
                })));
  }
}

class _List extends StatelessWidget {
  const _List(this.items, this.lead);
  final List<Knowledge> items;
  final String lead;
  @override
  Widget build(BuildContext context) => ListView(padding: pagePad(context), children: [
        Text(lead, style: TextStyle(color: AppColors.sub)),
        SizedBox(height: 12),
        if (items.isEmpty) Empty(noEvidence),
        for (final k in items)
          SoftCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(k.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
              if (k.risk != null) Text('위험 ${k.risk}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: k.risk == '높음' ? AppColors.accent : AppColors.sub)),
            ]),
            SizedBox(height: 8),
            Text(k.body, style: TextStyle(height: 1.5)),
            if (k.howTo != null) Padding(padding: EdgeInsets.only(top: 8), child: Text('신청: ${k.howTo}', style: TextStyle(color: AppColors.sub, height: 1.45))),
            if (k.asOf != null) Text('기준 ${k.asOf}', style: TextStyle(fontSize: 12, color: AppColors.sub)),
            SourceLink(k),
          ])),
      ]);
}
