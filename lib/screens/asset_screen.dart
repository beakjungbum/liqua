import 'package:flutter/material.dart';
import 'package:mm_app/models/asset.dart';
import 'package:mm_app/models/entry.dart';
import 'package:mm_app/services/asset_service.dart';
import 'package:mm_app/theme/app_theme.dart';

class AssetScreen extends StatefulWidget {
  final List<Entry> entries;
  final void Function(Entry entry)? onAdd;
  const AssetScreen({super.key, this.entries = const [], this.onAdd});
  @override
  State<AssetScreen> createState() => _AssetScreenState();
}

class _AssetScreenState extends State<AssetScreen> {
  final name = TextEditingController();
  final quantity = TextEditingController();
  final purchasePrice = TextEditingController();
  final currentPrice = TextEditingController();
  final memo = TextEditingController();
  var category = 0;
  var busy = false;
  Asset? editing;

  @override
  void dispose() {
    name.dispose();
    quantity.dispose();
    purchasePrice.dispose();
    currentPrice.dispose();
    memo.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final parsedQuantity = double.tryParse(quantity.text.trim());
    final parsedPurchase = double.tryParse(purchasePrice.text.trim());
    final parsedCurrent = double.tryParse(currentPrice.text.trim());
    final message = Asset.validate(
      name: name.text,
      category: Asset.categories[category],
      quantity: parsedQuantity,
      purchasePrice: parsedPurchase,
      currentPrice: parsedCurrent,
    );
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    setState(() => busy = true);
    try {
      final current = editing;
      if (current == null) {
        await AssetService.instance.add(
          name: name.text,
          category: Asset.categories[category],
          quantity: parsedQuantity!,
          purchasePrice: parsedPurchase!,
          currentPrice: parsedCurrent!,
          memo: memo.text,
        );
      } else {
        await AssetService.instance.update(
          id: current.id,
          name: name.text,
          category: Asset.categories[category],
          quantity: parsedQuantity!,
          purchasePrice: parsedPurchase!,
          currentPrice: parsedCurrent!,
          memo: memo.text,
        );
      }
      if (!mounted) return;
      clearForm();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('저장에 실패했습니다.\n$e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void clearForm() {
    name.clear();
    quantity.clear();
    purchasePrice.clear();
    currentPrice.clear();
    memo.clear();
    setState(() {
      category = 0;
      editing = null;
    });
  }

  void startEdit(Asset asset) {
    name.text = asset.name;
    quantity.text = _number(asset.quantity);
    purchasePrice.text = _number(asset.purchasePrice);
    currentPrice.text = _number(asset.currentPrice);
    memo.text = asset.memo ?? '';
    final index = Asset.categories.indexOf(asset.category);
    setState(() {
      category = index < 0 ? 0 : index;
      editing = asset;
    });
  }

  Future<void> remove(Asset asset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('자산 삭제'),
        content: Text('${asset.name}을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await AssetService.instance.delete(asset.id);
      if (editing?.id == asset.id && mounted) clearForm();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('삭제에 실패했습니다.\n$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: StreamBuilder<List<Asset>>(
            stream: AssetService.instance.watch(),
            builder: (context, snapshot) {
              final assets = snapshot.data ?? const <Asset>[];
              final total = assets.fold<double>(
                0,
                (sum, asset) => sum + asset.valuation,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '자산 기록',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '전체 자산 ${formatWon(total)}',
                    style: const TextStyle(fontSize: 16, color: AppColors.sub),
                  ),
                  if (snapshot.hasError) ...[
                    const SizedBox(height: 8),
                    Text('목록을 불러오지 못했습니다.\n${snapshot.error}'),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < Asset.categories.length; i++)
                        ChoiceChip(
                          label: Text(
                            Asset.categoryLabels[Asset.categories[i]]!,
                          ),
                          selected: category == i,
                          onSelected: busy
                              ? null
                              : (_) => setState(() => category = i),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(hintText: '자산 이름'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(hintText: '수량'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: purchasePrice,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(hintText: '매입 단가'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: currentPrice,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(hintText: '현재 단가'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: memo,
                    decoration: const InputDecoration(hintText: '메모 (선택)'),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: busy ? null : save,
                    child: Text(
                      busy ? '저장 중...' : (editing == null ? '추가' : '수정'),
                    ),
                  ),
                  if (editing != null)
                    TextButton(
                      onPressed: busy ? null : clearForm,
                      child: const Text('수정 취소'),
                    ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: assets.isEmpty
                        ? _empty()
                        : ListView(
                            children: [
                              for (final asset in assets)
                                _row(
                                  asset,
                                  onTap: () => startEdit(asset),
                                  onDelete: () => remove(asset),
                                ),
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

Widget _empty() => const Center(
  child: Text(
    '아직 자산이 없어요.\n이름, 수량, 단가를 입력해 추가해 보세요.',
    textAlign: TextAlign.center,
    style: TextStyle(color: AppColors.sub),
  ),
);

Widget _row(
  Asset asset, {
  required VoidCallback onTap,
  required VoidCallback onDelete,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: AppColors.surface,
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${asset.name} · ${asset.categoryLabel}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                formatWon(asset.valuation),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _number(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toString();
}