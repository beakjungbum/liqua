import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mm_app/data/models.dart';
import 'package:mm_app/domain/budget.dart';
import 'package:mm_app/domain/money.dart';
import 'package:mm_app/domain/notice_parser.dart';
import 'package:mm_app/screens/home_screen.dart';
import 'package:mm_app/services/device_service.dart';
import 'package:mm_app/theme/app_theme.dart';
import 'package:mm_app/ui/widgets.dart';

class TxnRow extends StatelessWidget {
  const TxnRow(this.t, {super.key});
  final Txn t;
  @override
  Widget build(BuildContext context) {
    final out = t.kind == TxnKind.expense;
    return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => sheet<void>(context, TxnForm(edit: t)),
        child: Padding(
            padding: EdgeInsets.symmetric(vertical: 9),
            child: Row(children: [
              IconTile(t.kind == TxnKind.income ? Icons.payments_outlined : t.kind == TxnKind.saving ? Icons.savings_outlined : categoryIcon(t.category)),
              SizedBox(width: 12),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.merchant, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600)),
                Text('${out ? '${t.category.label} · ' : ''}${t.source} · ${DateFormat('HH:mm').format(t.at)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppColors.sub)),
              ])),
              SizedBox(width: 8),
              if (!t.confirmed)
                IconButton(tooltip: '맞아요, 확정', onPressed: () => attempt(context, () => AppScope.read(context).confirmTxn(t)), icon: Icon(Icons.check_circle_outline, color: AppColors.accent)),
              ConstrainedBox(constraints: BoxConstraints(maxWidth: 120), child: FittedBox(fit: BoxFit.scaleDown, child: Text('${t.kind == TxnKind.income ? '+' : '−'}${won(t.amount)}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: t.kind == TxnKind.income ? AppColors.main : AppColors.text, fontFeatures: [FontFeature.tabularFigures()])))),
            ])));
  }
}

class BookScreen extends StatefulWidget {
  const BookScreen({super.key});
  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> with WidgetsBindingObserver {
  bool? capture;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    check();
  }

  Future<void> check() async {
    if (!DeviceService.instance.supportsCapture) return;
    try {
      final v = await DeviceService.instance.captureEnabled();
      if (mounted) setState(() => capture = v);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = AppScope.of(context);
    final byDay = <DateTime, List<Txn>>{};
    for (final t in m.txns) {
      (byDay[dateOnly(t.at)] ??= []).add(t);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    final unconfirmed = m.txns.where((t) => !t.confirmed).length;
    return CustomScrollView(slivers: [
      SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
          sliver: SliverList.list(children: [
            Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 4, children: [
              Text('가계부', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                TextButton(onPressed: () => push(context, FixedScreen()), child: Text('고정지출')),
                FilledButton(onPressed: () => sheet<void>(context, TxnForm()), style: FilledButton.styleFrom(minimumSize: Size(64, 42)), child: Text('기록')),
              ]),
            ]),
            SizedBox(height: 14),
            if (capture == false)
              SoftCard(
                  color: AppColors.mist,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('결제 알림을 자동으로 기록할까요?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    SizedBox(height: 4),
                    Text('다음 화면에서 Liqua를 켜 주세요. 결제로 보이는 알림만 저장하고 나머지는 바로 버려요.', style: TextStyle(color: AppColors.sub, height: 1.45)),
                    SizedBox(height: 12),
                    FilledButton(
                        onPressed: () async {
                          await DeviceService.instance.askPermission();
                          await DeviceService.instance.openCaptureSettings();
                        },
                        child: Text('자동 기록 켜기')),
                  ])),
            SoftCard(
                onTap: () => push(context, InsightScreen()),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Expanded(child: Text('이번 달 지출', style: TextStyle(color: AppColors.sub, fontWeight: FontWeight.w600))), Icon(Icons.chevron_right, color: AppColors.sub)]),
                  Won(m.monthTotal),
                  SizedBox(height: 10),
                  if (m.monthTotal > 0)
                    ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(height: 12, child: Row(children: [for (final (i, c) in m.monthByCategory.indexed) Expanded(flex: c.$2, child: ColoredBox(color: AppColors.chart[i], child: SizedBox.expand()))]))),
                ])),
            for (final n in m.pending)
              SoftCard(
                  color: AppColors.accentSoft,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('확인 필요 · ${n.app} ${DateFormat('M/d HH:mm').format(n.at)}', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text(n.raw, style: TextStyle(height: 1.4)),
                    if (n.isRefund) Padding(padding: EdgeInsets.only(top: 6), child: Text('취소 알림이에요. 아래 목록에서 원래 기록을 고치거나 지운 뒤 닫아 주세요.', style: TextStyle(fontSize: 13, color: AppColors.sub))),
                    Wrap(alignment: WrapAlignment.end, children: [
                      TextButton(onPressed: () => attempt(context, () => m.dismissNotice(n)), child: Text(n.isRefund ? '확인했어요' : '결제 아님')),
                      if (!n.isRefund) TextButton(onPressed: () => sheet<void>(context, TxnForm(notice: n)), child: Text('고쳐서 기록')),
                    ]),
                  ])),
            if (unconfirmed > 0) Padding(padding: EdgeInsets.only(bottom: 8), child: Text('자동 기록 $unconfirmed건은 확인 전이에요. 맞으면 체크를 눌러 주세요.', style: TextStyle(color: AppColors.sub, fontSize: 13))),
            if (days.isEmpty) Empty('아직 기록이 없어요.\n첫 지출을 기록해 보세요.'),
          ])),
      SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 28),
          sliver: SliverList.builder(
              itemCount: days.length,
              itemBuilder: (_, i) {
                final d = days[i], list = byDay[d]!;
                final sum = list.where((t) => t.kind == TxnKind.expense).fold(0, (a, t) => a + t.amount);
                return Column(children: [
                  Padding(
                      padding: EdgeInsets.only(top: 14, bottom: 2),
                      child: Row(children: [
                        Expanded(child: Text(DateFormat('M월 d일').format(d) + (d == m.today ? ' 오늘' : ''), style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.sub))),
                        Text(won(sum), style: TextStyle(color: AppColors.sub)),
                      ])),
                  for (final t in list) TxnRow(t),
                ]);
              })),
    ]);
  }
}

class TxnForm extends StatefulWidget {
  const TxnForm({super.key, this.edit, this.notice});
  final Txn? edit;
  final PendingNotice? notice;
  @override
  State<TxnForm> createState() => _TxnFormState();
}

class _TxnFormState extends State<TxnForm> {
  final form = GlobalKey<FormState>();
  late final amount = TextEditingController(text: widget.edit == null ? _guess() : comma(widget.edit!.amount));
  late final merchant = TextEditingController(text: widget.edit?.merchant ?? '');
  late var category = widget.edit?.category ?? Category.food;
  late var kind = widget.edit?.kind ?? TxnKind.expense;
  var touched = false;

  String _guess() {
    final m = RegExp(r'([\d,]+)\s*원').firstMatch(widget.notice?.raw ?? '');
    final v = m == null ? null : parseWon(m[1]!);
    return v == null ? '' : comma(v);
  }

  @override
  void dispose() {
    amount.dispose();
    merchant.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = AppScope.read(context);
    final e = widget.edit;
    return Form(
        key: form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e != null ? '기록 고치기' : widget.notice != null ? '알림 고쳐서 기록' : '새 기록', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          SizedBox(height: 14),
          if (e == null && widget.notice == null) ...[
            Wrap(spacing: 8, children: [
              for (final (k, l) in [(TxnKind.expense, '지출'), (TxnKind.income, '수입')]) ChoiceChip(label: Text(l), selected: kind == k, onSelected: (_) => setState(() => kind = k))
            ]),
            SizedBox(height: 12),
          ],
          if (e?.kind == TxnKind.saving) Text('저축 ${won(e!.amount)}. 지우면 저축 자산에서도 빠져요.') else MoneyField(amount, '금액'),
          TextFormField(
              controller: merchant,
              maxLength: 40,
              onChanged: (s) {
                if (!touched && kind == TxnKind.expense) setState(() => category = categorize(s));
              },
              validator: (s) => (s ?? '').trim().isEmpty ? '어디에 썼는지 적어 주세요' : null,
              decoration: InputDecoration(labelText: kind == TxnKind.income ? '어디서 받았나요' : '가맹점', counterText: '')),
          SizedBox(height: 14),
          if (kind == TxnKind.expense)
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final c in Category.values)
                ChoiceChip(label: Text(c.label), selected: category == c, onSelected: (_) => setState(() {
                      category = c;
                      touched = true;
                    }))
            ]),
          SizedBox(height: 18),
          SaveButton('저장', () async {
            if (!form.currentState!.validate()) return;
            final v = e?.kind == TxnKind.saving ? e!.amount : parseWon(amount.text)!, name = merchant.text.trim();
            final ok = await attempt(context, () async {
              if (e != null) {
                await m.updateTxn(e.copyWith(amount: v, merchant: name, category: category, confirmed: true));
              } else if (widget.notice != null) {
                await m.resolveNotice(widget.notice!, v, name, category);
              } else {
                await m.addTxn(kind, v, name, category, m.now);
              }
            });
            if (ok && context.mounted) Navigator.pop(context);
          }),
          if (e != null)
            Center(child: TextButton(
                onPressed: () async {
                  final ok = await attempt(context, () => m.deleteTxn(e.id));
                  if (ok && context.mounted) Navigator.pop(context);
                },
                child: Text('이 기록 지우기', style: TextStyle(color: AppColors.accent)))),
        ]));
  }
}

class FixedScreen extends StatelessWidget {
  const FixedScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final m = AppScope.of(context);
    return Scaffold(
        appBar: AppBar(title: Text('고정지출')),
        body: ListView(padding: pagePad(context), children: [
          Text('결제일 하루 전 오전 9시에 알려 드리고, 생활비에서 먼저 빼요.', style: TextStyle(color: AppColors.sub)),
          SizedBox(height: 14),
          if (m.fixed.isEmpty) Empty('구독료나 대출 상환금을 등록해 보세요'),
          for (final f in m.fixed)
            SoftCard(
                onTap: () => sheet<void>(context, FixedForm(edit: f)),
                child: Row(children: [
                  IconTile(f.remind ? Icons.notifications_active_outlined : Icons.notifications_off_outlined),
                  SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(f.name, style: TextStyle(fontWeight: FontWeight.w700)),
                    Text('매달 ${f.day}일 · ${DateFormat('M/d').format(f.nextDue(m.today))} 예정', style: TextStyle(color: AppColors.sub, fontSize: 13)),
                  ])),
                  Text(won(f.amount), style: TextStyle(fontWeight: FontWeight.w700)),
                ])),
          SizedBox(height: 8),
          FilledButton(onPressed: () => sheet<void>(context, FixedForm()), child: Text('고정지출 추가')),
        ]));
  }
}

class FixedForm extends StatefulWidget {
  const FixedForm({super.key, this.edit});
  final FixedExpense? edit;
  @override
  State<FixedForm> createState() => _FixedFormState();
}

class _FixedFormState extends State<FixedForm> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.edit?.name ?? '');
  late final amount = TextEditingController(text: widget.edit == null ? '' : comma(widget.edit!.amount));
  late var day = widget.edit?.day ?? 1;
  late var remind = widget.edit?.remind ?? true;

  @override
  void dispose() {
    name.dispose();
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = AppScope.read(context);
    return Form(
        key: form,
        child: Column(children: [
          TextFormField(controller: name, maxLength: 30, decoration: InputDecoration(labelText: '이름', counterText: ''), validator: (s) => (s ?? '').trim().isEmpty ? '이름을 적어 주세요' : null),
          SizedBox(height: 12),
          MoneyField(amount, '금액'),
          DropdownButtonFormField<int>(isExpanded: true, 
              initialValue: day, decoration: InputDecoration(labelText: '결제일'),
              items: [for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text('매달 $d일'))], onChanged: (v) => day = v ?? 1),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: remind, onChanged: (v) => setState(() => remind = v), title: Text('하루 전 알림')),
          SaveButton('저장', () async {
            if (!form.currentState!.validate()) return;
            final ok = await attempt(context, () async {
              if (remind) await DeviceService.instance.askPermission().catchError((_) => false);
              await m.saveFixed(FixedExpense(id: widget.edit?.id ?? '', name: name.text.trim(), amount: parseWon(amount.text)!, day: day, remind: remind));
            });
            if (ok && context.mounted) Navigator.pop(context);
          }),
          if (widget.edit != null)
            TextButton(
                onPressed: () async {
                  final ok = await attempt(context, () => m.deleteFixed(widget.edit!.id));
                  if (ok && context.mounted) Navigator.pop(context);
                },
                child: Text('이 고정지출 지우기', style: TextStyle(color: AppColors.accent))),
        ]));
  }
}
