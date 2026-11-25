import 'package:flutter/material.dart';
import 'package:mm_app/domain/money.dart';
import 'package:mm_app/models/asset.dart';
import 'package:mm_app/services/fx_service.dart';
import 'package:mm_app/theme/app_theme.dart';
import 'package:mm_app/ui/widgets.dart';

class AssetScreen extends StatefulWidget {
  const AssetScreen({super.key});
  @override
  State<AssetScreen> createState() => _AssetScreenState();
}

Currency? currencyOf(Asset a) => a.category != 'fx' ? null : Currency.values.where((c) => a.name.contains(c.label) || a.name.contains(c.code)).firstOrNull;

class _AssetScreenState extends State<AssetScreen> {
  FxQuote? fx;
  var loading = true;
  var filter = 'all';

  @override
  void initState() {
    super.initState();
    refresh();
  }

  /// 새 환율이면 외화 자산의 현재 단가를 갱신한다.
  Future<void> refresh() async {
    final m = AppScope.read(context);
    final q = await FxService().load();
    if (!mounted) return;
    setState(() {
      fx = q;
      loading = false;
    });
    if (q == null || q.stale) return;
    for (final a in [...m.assets]) {
      final r = q.rates[currencyOf(a)?.code];
      if (r != null && (r - a.currentPrice).abs() > .0001) {
        try {
          await m.saveAsset(Asset(id: a.id, name: a.name, category: a.category, quantity: a.quantity, purchasePrice: a.purchasePrice, currentPrice: r, memo: a.memo));
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = AppScope.of(context);
    final groups = <String, int>{};
    for (final a in m.assets) {
      groups[a.category] = (groups[a.category] ?? 0) + a.valuation.round();
    }
    final keys = groups.keys.toList()..sort((a, b) => groups[b]!.compareTo(groups[a]!));
    final shares = percentShares([for (final k in keys) groups[k]!]);
    final shown = m.assets.where((a) => filter == 'all' || a.category == filter).toList();
    final prev = m.previousSnapshot;
    final diff = prev == null ? null : m.total - prev.total;
    final trend = [...m.snapshots.where((s) => s.at.isBefore(m.today)).map((s) => s.total), m.total];
    final fxSum = groups['fx'] ?? 0;
    return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 28), children: [
          const Text('나의 저축', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          SoftCard(
              color: AppColors.olive,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('나의 총 자산', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                Won(m.total, size: 36, color: Colors.white),
                Text(diff == null ? '내일부터 변화를 보여 드려요' : '지난 기록보다 ${diff >= 0 ? '+' : ''}${won(diff)}', style: const TextStyle(color: Color(0xFFF1F3E6))),
                if (trend.length > 1) Padding(padding: const EdgeInsets.only(top: 8), child: TrendLine(trend.length > 30 ? trend.sublist(trend.length - 30) : trend)),
              ])),
          if (keys.isNotEmpty)
            SoftCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('자산 구성 비율', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              SizedBox(
                  height: 150,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    for (final (i, k) in keys.indexed)
                      Expanded(
                          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        Text('${shares[i]}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Container(width: 34, height: 8 + 84.0 * shares[i] / (shares.first == 0 ? 1 : shares.first), decoration: BoxDecoration(color: AppColors.chart[i], borderRadius: const BorderRadius.vertical(top: Radius.circular(7)))),
                        const Divider(),
                        Padding(padding: const EdgeInsets.only(top: 4), child: Text(Asset.categoryLabels[k] ?? k, maxLines: 1, style: const TextStyle(fontSize: 12))),
                        FittedBox(child: Text(won(groups[k]!), style: const TextStyle(fontSize: 11, color: AppColors.sub))),
                      ])),
                  ])),
            ])),
          if (fxSum > 0)
            SoftCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('외화 자산', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Won(fxSum, size: 24),
              Text('환율이 1% 오르면 +${won((fxSum * .01).round())}', style: const TextStyle(color: AppColors.sub)),
              const SizedBox(height: 6),
              for (final c in Currency.values)
                if (fx?.rates[c.code] != null && m.assets.any((a) => currencyOf(a) == c))
                  Text('${c.label} ${c.unit == 1 ? '' : '${c.unit}'}${c.code} = ${comma((fx!.rates[c.code]! * c.unit * 100).round() / 100)}원${fx!.change(c.code) == null ? '' : ' (${fx!.change(c.code)! >= 0 ? '+' : ''}${fx!.change(c.code)!.toStringAsFixed(2)}%)'}', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 4),
              Text(loading ? '환율을 불러오는 중' : fx == null ? '환율을 불러오지 못했어요. 아래로 당겨 다시 시도해 주세요.' : '${fx!.source} ${fx!.date}${fx!.stale ? ' (연결이 끊겨 마지막 환율)' : ''}', style: TextStyle(fontSize: 12, color: fx?.stale ?? !loading && fx == null ? AppColors.accent : AppColors.sub)),
            ])),
          SoftCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('자산 추가하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const Text('새로운 자산을 등록해 보세요.', style: TextStyle(color: AppColors.sub)),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: () => sheet<void>(context, AssetForm(fx: fx)), child: const Text('자산 추가하기'))),
          ])),
          const Section('보유 자산 목록'),
          const SizedBox(height: 6),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final k in ['all', ...keys]) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(k == 'all' ? '전체' : Asset.categoryLabels[k] ?? k), selected: filter == k, onSelected: (_) => setState(() => filter = k)))
              ])),
          const SizedBox(height: 10),
          if (shown.isEmpty) const Empty('아직 등록한 자산이 없어요'),
          for (final a in shown)
            SoftCard(
                color: AppColors.mist, padding: const EdgeInsets.all(14), onTap: () => sheet<void>(context, AssetForm(edit: a, fx: fx)),
                child: Row(children: [
                  IconTile(_icon(a.category), color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(a.categoryLabel, style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(won(a.valuation.round()), style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (['stock', 'etf', 'crypto', 'fx'].contains(a.category) && a.purchasePrice > 0)
                      Text(_gain(a), style: TextStyle(fontSize: 12, color: a.currentPrice >= a.purchasePrice ? AppColors.sub : AppColors.accent)),
                  ]),
                ])),
        ]));
  }

  String _gain(Asset a) {
    final p = (a.currentPrice - a.purchasePrice) / a.purchasePrice * 100;
    return '${p >= 0 ? '+' : ''}${p.toStringAsFixed(1)}%';
  }
}

IconData _icon(String c) => switch (c) {
      'cash' => Icons.account_balance_wallet_outlined,
      'deposit' => Icons.savings_outlined,
      'stock' => Icons.show_chart,
      'etf' => Icons.donut_small_outlined,
      'fx' => Icons.currency_exchange,
      'crypto' => Icons.currency_bitcoin,
      _ => Icons.category_outlined,
    };

class AssetForm extends StatefulWidget {
  const AssetForm({super.key, this.edit, this.fx});
  final Asset? edit;
  final FxQuote? fx;
  @override
  State<AssetForm> createState() => _AssetFormState();
}

class _AssetFormState extends State<AssetForm> {
  final form = GlobalKey<FormState>();
  late var category = widget.edit?.category ?? 'cash';
  late var currency = widget.edit == null ? Currency.usd : currencyOf(widget.edit!) ?? Currency.usd;
  late final name = TextEditingController(text: widget.edit?.name ?? '');
  late final amount = TextEditingController(text: widget.edit == null ? '' : comma(widget.edit!.valuation.round()));
  late final qty = TextEditingController(text: widget.edit == null ? '' : _num(widget.edit!.quantity));
  late final buy = TextEditingController(text: widget.edit == null ? '' : _num(widget.edit!.purchasePrice));
  late final cur = TextEditingController(text: widget.edit == null ? '' : _num(widget.edit!.currentPrice));

  static String _num(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';
  bool get simple => ['cash', 'deposit', 'other'].contains(category);
  bool get isFx => category == 'fx';

  @override
  void dispose() {
    for (final c in [name, amount, qty, buy, cur]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget number(TextEditingController c, String label, {String? suffix}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, suffixText: suffix),
          validator: (s) {
            final v = double.tryParse((s ?? '').replaceAll(',', ''));
            return v == null || !v.isFinite ? '숫자로 입력해 주세요' : v < 0 ? '0 이상이어야 해요' : v > 1e12 ? '너무 큰 값이에요' : null;
          }));

  @override
  Widget build(BuildContext context) {
    final m = AppScope.read(context);
    double d(TextEditingController c) => double.parse(c.text.replaceAll(',', ''));
    final rate = widget.fx?.rates[currency.code];
    return Form(
        key: form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.edit == null ? '자산 추가' : '자산 고치기', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Wrap(spacing: 8, children: [
            for (final c in Asset.categories) ChoiceChip(label: Text(Asset.categoryLabels[c]!), selected: category == c, onSelected: (_) => setState(() => category = c))
          ]),
          const SizedBox(height: 12),
          if (isFx)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<Currency>(
                    initialValue: currency, decoration: const InputDecoration(labelText: '통화'),
                    items: [for (final c in Currency.values) DropdownMenuItem(value: c, child: Text('${c.label} (${c.code})'))],
                    onChanged: (v) => setState(() => currency = v ?? currency)))
          else
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(controller: name, maxLength: 40, decoration: const InputDecoration(labelText: '이름', counterText: ''), validator: (s) => (s ?? '').trim().isEmpty ? '이름을 적어 주세요' : null)),
          if (simple) MoneyField(amount, '금액', allowZero: true) else number(qty, isFx ? '보유 금액' : '수량', suffix: isFx ? currency.code : null),
          if (!simple) number(buy, isFx ? '살 때 환율 (1${currency.code}당 원)' : '매입 단가', suffix: '원'),
          if (!simple && (!isFx || rate == null)) number(cur, isFx ? '지금 환율 (1${currency.code}당 원)' : '현재 단가', suffix: '원'),
          if (isFx && rate != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('지금 환율 1${currency.code} = ${rate.toStringAsFixed(2)}원 (${widget.fx!.source})', style: const TextStyle(color: AppColors.sub))),
          SaveButton('저장', () async {
            if (!form.currentState!.validate()) return;
            final v = simple ? parseWon(amount.text)!.toDouble() : 0.0;
            final ok = await attempt(context, () => m.saveAsset(Asset(
                id: widget.edit?.id ?? '',
                name: isFx ? currency.label : name.text.trim(),
                category: category,
                quantity: simple ? 1 : d(qty),
                purchasePrice: simple ? v : d(buy),
                currentPrice: simple ? v : isFx && rate != null ? rate : d(cur))));
            if (ok && context.mounted) Navigator.pop(context);
          }),
          if (widget.edit != null)
            Center(child: TextButton(
                onPressed: () async {
                  final ok = await attempt(context, () => m.deleteAsset(widget.edit!.id));
                  if (ok && context.mounted) Navigator.pop(context);
                },
                child: const Text('이 자산 지우기', style: TextStyle(color: AppColors.accent)))),
        ]));
  }
}
