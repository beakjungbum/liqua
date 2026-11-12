import 'package:flutter/material.dart';
import 'package:mm_app/theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final List<String> questions;
  final void Function(String text)? onAsk;
  const ChatScreen({super.key, this.questions = const [], this.onAsk});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final controller = TextEditingController();
  static const hints = ['이번 달 식비가 많나?', '목표까지 얼마나 남았나?'];
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void ask() {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    widget.onAsk?.call(text);
    controller.clear();
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
                '자산 도우미',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const Text(
                '오늘은 질문만 남기고, 답은 5주차에 연결해요',
                style: TextStyle(color: AppColors.sub),
              ),
              const SizedBox(height: 10),
              for (final h in hints)
                ActionChip(
                  label: Text(h),
                  onPressed: () => controller.text = h,
                ),
              Expanded(
                child: ListView(
                  children: [for (final t in widget.questions) _bubble(t)],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(hintText: '질문 입력'),
                    ),
                  ),
                  IconButton(onPressed: ask, icon: const Icon(Icons.send)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _bubble(String text) => Align(
  alignment: Alignment.centerRight,
  child: Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: const BoxDecoration(
      color: AppColors.primary,
      borderRadius: BorderRadius.all(Radius.circular(16)),
    ),
    child: Text(text, style: const TextStyle(color: AppColors.surface)),
  ),
);
