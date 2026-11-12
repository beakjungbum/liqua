import 'package:flutter/material.dart';
import 'package:mm_app/theme/app_theme.dart';
import 'package:flutter/services.dart';

class GoalScreen extends StatefulWidget {
  final int goal;
  final void Function(int value)? onSave;
  const GoalScreen({super.key, this.goal = 0, this.onSave});
  @override
  State<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends State<GoalScreen> {
  late final TextEditingController controller;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final text = widget.goal == 0 ? '' : '${widget.goal}';
    controller = TextEditingController(text: text);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final parsed = int.tryParse(controller.text);
    if (parsed == null || parsed <= 0) {
      const msg = SnackBar(content: Text('1원 이상 숫자로 입력하세요'));
      ScaffoldMessenger.of(context).showSnackBar(msg);
      return;
    }
    setState(() => busy = true);
    await Future.delayed(const Duration(milliseconds: 500)); // DB 자리
    if (!mounted) return;
    widget.onSave?.call(parsed);
    setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final subText = widget.goal == 0
        ? '모으고 싶은 금액 (달성률 기준)'
        : '현재 목표 금액: ${widget.goal}원';
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '목표 설정',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(subText, style: const TextStyle(color: AppColors.primary)),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: '목표 금액 (원)'),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: busy ? null : save,
                child: const Text('저장'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
