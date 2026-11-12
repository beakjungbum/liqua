import 'package:flutter/material.dart';
import 'package:mm_app/models/entry.dart';
import 'package:mm_app/theme/app_theme.dart';
class HomeScreen extends StatelessWidget {
  final List<Entry> entries;
  final int goal;
  final void Function()? onSettings;
  const HomeScreen({
  super.key, this.entries = const [], this.goal = 0, this.onSettings,
  });
  @override
  Widget build(BuildContext context) {
    final income = entries.where((e) => e.income).fold(0, (s, e) => s + e.amount);
    final expense = entries.where((e) => !e.income).fold(0, (s, e) => s + e.amount);
    final food = entries
    .where((e) => !e.income && e.category == '식비')
    .fold(0, (s, e) => s + e.amount);
    final asset = income - expense;
    final rate = goal <= 0 || asset <= 0 ? 0.0 : (asset / goal).clamp(0.0, 1.0);
    final percent = (rate * 100).round();
    final empty = entries.isEmpty;
    return Scaffold(body: SafeArea(child: ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Row(children: [
        const Text('내 순자산', style: TextStyle(color: AppColors.sub)),
        const Spacer(),
        IconButton(
          onPressed: onSettings,
          icon: const Icon(Icons.settings_outlined),
        ),
      ]),
    Text(empty ? '0원' : '$asset원',
    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800)),
    const SizedBox(height: 6),
    Text(empty ? '자산 탭에서 첫 내역을 기록해 보세요!' : '수입 +$income원 · 지출 -$expense원',
    style: const TextStyle(fontSize: 14, color: AppColors.sub)),
    const SizedBox(height: 24),
      _card('목표 달성률', '$percent%', rate),
      const SizedBox(height: 12),
      _card('이번 달 식비', '$food원', null),
    ],
)));
}
}
Widget _card(String title, String value, double? bar) => Container(
width: double.infinity,
padding: const EdgeInsets.all(20),
decoration: const BoxDecoration(
color: AppColors.surface,
borderRadius: BorderRadius.all(Radius.circular(20)),
),
child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
Text(title, style: const TextStyle(fontSize: 14, color: AppColors.sub)),
const SizedBox(height: 8),
Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
if (bar != null) const SizedBox(height: 14),
if (bar != null)
ClipRRect(
borderRadius: const BorderRadius.all(Radius.circular(8)),
child: LinearProgressIndicator(
value: bar, minHeight: 10,
backgroundColor: AppColors.background, color: AppColors.primary,
),
),
]),
);