import 'package:flutter/material.dart';
import 'package:mm_app/theme/app_theme.dart';
import 'package:mm_app/models/entry.dart';
import 'package:flutter/services.dart';

class AssetScreen extends StatefulWidget {
  final List<Entry> entries;
  final void Function(Entry entry)? onAdd;
  const AssetScreen({super.key, this.entries = const [], this.onAdd});
  @override
  State<AssetScreen> createState() => _AssetScreenState();
}

class _AssetScreenState extends State<AssetScreen> {
  final controller = TextEditingController();
  bool income = false, busy = false;
  int category = 0;
  static const categories = ['식비', '교통', '생활'];
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> add() async {
    final parsed = int.tryParse(controller.text);
    if (parsed == null || parsed <= 0) {
      const msg = SnackBar(content: Text('1원 이상 숫자로 입력하세요'));
      ScaffoldMessenger.of(context).showSnackBar(msg);
      return;
    }
    setState(() => busy = true); // 저장 중 버튼 잠금
    await Future.delayed(const Duration(milliseconds: 500)); // DB 자리
    if (!mounted) return;
    widget.onAdd?.call(
      Entry(income: income, category: categories[category], amount: parsed),
    );
    controller.clear();
    setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '자산 기록',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('지출'),
                    selected: !income,
                    onSelected: busy
                        ? null
                        : (_) => setState(() => income = false),
                  ),
                  ChoiceChip(
                    label: const Text('수입'),
                    selected: income,
                    onSelected: busy
                        ? null
                        : (_) => setState(() => income = true),
                  ),
                  for (var i = 0; i < categories.length; i++)
                    ChoiceChip(
                      label: Text(categories[i]),
                      selected: category == i,
                      onSelected: busy
                          ? null
                          : (_) => setState(() => category = i),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: '금액 (원)'),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: busy ? null : add,
                child: Text(busy ? '저장 중...' : '추가'),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: widget.entries.isEmpty
                    ? _empty()
                    : ListView(
                        children: [for (final e in widget.entries) _row(e)],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _empty() => const Center(
  child: Text(
    '아직 기록이 없어요.\n첫 수입이나 지출을 추가해 보세요!',
    textAlign: TextAlign.center,
    style: TextStyle(color: AppColors.sub),
  ),
);

Widget _row(Entry e) => Container(
  margin: const EdgeInsets.only(bottom: 10),
  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
  decoration: const BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.all(Radius.circular(16)),
  ),
  child: Row(
    children: [
      Text(
        '${e.income ? '수입' : '지출'} · ${e.category}',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      const Spacer(),
      Text(
        '${e.income ? '+' : '-'}${e.amount}원',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: e.income ? AppColors.primary : AppColors.expense,
        ),
      ),
    ],
  ),
);
