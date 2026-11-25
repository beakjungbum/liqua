import 'package:flutter/material.dart';
import 'package:mm_app/data/models.dart';
import 'package:mm_app/domain/budget.dart';
import 'package:mm_app/domain/growth.dart';
import 'package:mm_app/domain/interview.dart';
import 'package:mm_app/domain/money.dart';
import 'package:mm_app/theme/app_theme.dart';
import 'package:mm_app/ui/widgets.dart';

class Onboarding extends StatelessWidget {
  const Onboarding({super.key, required this.onExit});
  final VoidCallback onExit;
  @override
  Widget build(BuildContext context) {
    final m = AppScope.of(context);
    return m.profile.complete ? PlanScreen(first: true, onExit: onExit) : InterviewScreen(onExit: onExit);
  }
}

class InterviewScreen extends StatefulWidget {
  const InterviewScreen({super.key, this.onExit});

  /// 처음 쓸 때만 있다. 다시 하기에서는 뒤로 가기를 쓴다.
  final VoidCallback? onExit;
  @override
  State<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends State<InterviewScreen> {
  var p = Profile();
  var step = 0;
  final log = <(bool, String)>[];
  final input = TextEditingController();
  final scroll = ScrollController();

  Ask get ask => Ask.values[step];
  bool get done => step >= Ask.values.length;

  @override
  void initState() {
    super.initState();
    log.add((false, '안녕하세요. 맞춤 안내를 하려고 여섯 가지만 물어볼게요. 답은 나중에 바꿀 수 있어요.'));
    log.add((false, questions[ask]!.$1));
  }

  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void send(String raw) {
    if (raw.trim().isEmpty || done) return;
    final next = answer(p, ask, raw);
    setState(() {
      log.add((true, raw.trim()));
      input.clear();
      if (next == null) {
        log.add((false, '잘 못 알아들었어요. ${questions[ask]!.$1}'));
      } else {
        p = next;
        step++;
        log.add((false, done
            ? '만 ${p.age}세, 월 ${won(p.monthlyIncome!)}, ${p.region}, 투자 경험 ${p.experience}, 위험 ${p.risk}으로 이해했어요. 맞나요?'
            : questions[ask]!.$1));
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = AppScope.read(context);
    return Scaffold(
        appBar: AppBar(
            title: Text('첫 인터뷰'),
            actions: [
              Center(child: Text('${done ? Ask.values.length : step + 1} / ${Ask.values.length}', style: TextStyle(color: AppColors.sub, fontWeight: FontWeight.w700))),
              SizedBox(width: 12),
              if (widget.onExit != null) TextButton(onPressed: widget.onExit, child: Text('나가기'))],
            bottom: PreferredSize(preferredSize: Size.fromHeight(6), child: Bar(step / Ask.values.length, height: 6))),
        body: SafeArea(
            child: Column(children: [
          Expanded(child: ListView(controller: scroll, padding: EdgeInsets.all(20), children: [for (final (me, t) in log) Bubble(t, me: me)])),
          if (done)
            Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(children: [
                  TextButton(
                      onPressed: () => setState(() {
                            p = Profile();
                            step = 0;
                            log
                              ..add((true, '다시 할게요'))
                              ..add((false, questions[ask]!.$1));
                          }),
                      child: Text('다시 답하기')),
                  SizedBox(width: 8),
                  Expanded(
                      child: SaveButton('맞아요', () async {
                    final ok = await attempt(context, () => m.saveProfile(p));
                    if (ok && context.mounted && widget.onExit == null) closeThis(context);
                  })),
                ]))
          else ...[
            if (questions[ask]!.$2.isNotEmpty)
              SizedBox(
                  height: 48,
                  child: ListView(scrollDirection: Axis.horizontal, padding: EdgeInsets.symmetric(horizontal: 20), children: [
                    for (final o in questions[ask]!.$2) Padding(padding: EdgeInsets.only(right: 8), child: ActionChip(label: Text(o), onPressed: () => send(o)))
                  ])),
            Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 12, 16),
                child: Row(children: [
                  Expanded(child: TextField(controller: input, onSubmitted: send, textInputAction: TextInputAction.send, decoration: InputDecoration(hintText: '편하게 답해 주세요'))),
                  IconButton(tooltip: '보내기', onPressed: () => send(input.text), icon: Icon(Icons.arrow_upward_rounded, color: AppColors.olive)),
                ])),
          ],
        ])));
  }
}

class Bubble extends StatelessWidget {
  const Bubble(this.text, {super.key, this.me = false, this.child});
  final String text;
  final bool me;
  final Widget? child;
  @override
  Widget build(BuildContext context) => Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
          margin: EdgeInsets.only(bottom: 8, left: me ? 48 : 0, right: me ? 0 : 32),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
              color: me ? AppColors.main : AppColors.card,
              borderRadius: BorderRadius.circular(20).copyWith(bottomRight: me ? Radius.circular(6) : null, bottomLeft: me ? null : Radius.circular(6))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SelectableText(text, style: TextStyle(color: me ? AppColors.ink : AppColors.text, height: 1.5)),
            ?child,
          ])));
}

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key, this.first = false, this.onExit});
  final bool first;
  final VoidCallback? onExit;
  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final form = GlobalKey<FormState>();
  final living = TextEditingController(), monthly = TextEditingController(), saving = TextEditingController(), target = TextEditingController();
  int? payday = 25;
  var loaded = false;
  var restart = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loaded) return;
    loaded = true;
    final m = AppScope.of(context);
    final s = m.settings;
    if (s != null) {
      final firstNow = m.plan!.start == dateOnly(s.start);
      living.text = comma(firstNow ? s.firstLiving ?? s.living : s.living);
      monthly.text = comma(s.living);
      saving.text = comma(s.saving);
      payday = s.payday;
    }
    if (m.target > 0) target.text = comma(m.target);
    for (final c in [living, monthly, saving]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    living.dispose();
    monthly.dispose();
    saving.dispose();
    target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = AppScope.of(context);
    final l = parseWon(living.text), s = parseWon(saving.text) ?? 0;
    final old = m.settings;
    final fresh = old == null || restart;
    final start = fresh ? m.today : old.start;
    // 첫 기간이 한 달보다 짧으면 그다음 달 금액을 따로 묻는다.
    final probe = PlanSettings(living: 0, saving: 0, start: start, payday: payday).planFor(m.now, []);
    final partial = probe.start == dateOnly(start) && probe.days < 28;
    final month = partial ? parseWon(monthly.text) ?? l : l;
    final draft = PlanSettings(living: month ?? 0, firstLiving: partial ? l : probe.start == dateOnly(start) ? null : old?.firstLiving, saving: s, start: start, payday: payday);
    final plan = draft.planFor(m.now, m.fixed);
    return Scaffold(
        appBar: AppBar(title: Text(widget.first ? '하루 생활비 정하기' : '생활비 설정'), actions: [if (widget.onExit != null) TextButton(onPressed: widget.onExit, child: Text('나가기'))]),
        body: SafeArea(
            child: Form(
                key: form,
                child: ListView(padding: pagePad(context), children: [
                  MoneyField(living, partial ? '다음 수입일까지 쓸 생활비' : '한 기간에 쓸 생활비', helper: '고정지출과 저축할 돈을 포함한 금액이에요'),
                  if (partial) MoneyField(monthly, '그다음부터 한 달 생활비', helper: '수입일이 지나면 이 금액으로 바뀌어요'),
                  MoneyField(saving, '먼저 저축할 금액', allowZero: true),
                  if (widget.first) MoneyField(target, '모으고 싶은 목표 금액'),
                  DropdownButtonFormField<int?>(isExpanded: true, 
                      initialValue: payday,
                      decoration: InputDecoration(labelText: '수입일'),
                      items: [
                        DropdownMenuItem(value: null, child: Text('정해진 날 없음 (30일 단위)')),
                        for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text('매달 $d일'))
                      ],
                      onChanged: (v) => setState(() => payday = v)),
                  if (old != null && !widget.first)
                    SwitchListTile(contentPadding: EdgeInsets.zero, value: restart, onChanged: (v) => setState(() => restart = v), title: Text('오늘부터 새 기간 시작'), subtitle: Text('켜면 이월과 초과를 처음부터 다시 세요')),
                  SizedBox(height: 16),
                  if (l != null && l > 0)
                    SoftCard(
                        color: AppColors.mist,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('하루에 쓸 수 있는 돈', style: TextStyle(fontWeight: FontWeight.w700)),
                          Won(plan.base(m.today), size: 34),
                          Text('(${comma(l)} − 고정지출 ${comma(plan.fixed)} − 저축 ${comma(s)}) ÷ ${plan.days}일', style: TextStyle(color: AppColors.sub)),
                          if (plan.pool == 0) Text('고정지출과 저축이 생활비보다 커요', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
                        ])),
                  SizedBox(height: 8),
                  SaveButton(widget.first ? '시작하기' : '저장', () async {
                    if (!form.currentState!.validate()) return;
                    final ok = await attempt(context, () async {
                      if (widget.first) await m.setTarget(parseWon(target.text)!);
                      await m.saveSettings(draft);
                    });
                    if (ok && context.mounted && !widget.first) closeThis(context);
                  }),
                  if (widget.first) Padding(padding: EdgeInsets.only(top: 8), child: Text('다 채우면 ${PetStage.seed.label} 펫을 만나요', textAlign: TextAlign.center, style: TextStyle(color: AppColors.sub))),
                ]))));
  }
}
