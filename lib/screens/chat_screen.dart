import 'package:flutter/material.dart';
import 'package:mm_app/services/chat_service.dart';
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
  var _sending = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> ask() async {
    final text = controller.text.trim();
    if (text.isEmpty || _sending) return;
    final includeSummary = ChatService.includesProgressSummary(text);
    _sending = true;
    widget.onAsk?.call(text);
    controller.clear();
    setState(() {
      ChatService.instance.messages.add(
        ChatLine(text: text, fromUser: true, includedSummary: includeSummary),
      );
    });
    try {
      final answer = await ChatService.instance.ask(text);
      ChatService.instance.messages.add(
        ChatLine(text: answer, fromUser: false),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(messageForChatError(e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
                '질문 하나를 보내면 Gemini 답변을 보여 줘요',
                style: TextStyle(color: AppColors.sub),
              ),
              const SizedBox(height: 10),
              for (final h in hints)
                ActionChip(
                  label: Text(h),
                  onPressed: _sending ? null : () => controller.text = h,
                ),
              Expanded(
                child: ListView(
                  children: [
                    for (final message in ChatService.instance.messages)
                      _bubble(message),
                    if (_sending) const _LoadingBubble(),
                  ],
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  if (!ChatService.includesProgressSummary(value.text)) {
                    return const SizedBox.shrink();
                  }
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      '이 질문에는 총 자산, 목표 금액, 달성률만 함께 보냅니다. 이름·메모·이메일은 보내지 않습니다.',
                      style: TextStyle(fontSize: 12, color: AppColors.sub),
                    ),
                  );
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: !_sending,
                      decoration: const InputDecoration(hintText: '질문 입력'),
                      onSubmitted: _sending ? null : (_) => ask(),
                    ),
                  ),
                  IconButton(
                    onPressed: _sending ? null : ask,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _bubble(ChatLine message) {
  final fromUser = message.fromUser;
  return Align(
    alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: fromUser ? AppColors.primary : AppColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.text,
            style: TextStyle(
              color: fromUser ? AppColors.surface : AppColors.text,
            ),
          ),
          if (message.includedSummary)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '총 자산·목표 금액·달성률만 함께 보냄',
                style: TextStyle(fontSize: 11, color: AppColors.surface),
              ),
            ),
        ],
      ),
    ),
  );
}

class _LoadingBubble extends StatelessWidget {
  const _LoadingBubble();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('답변을 받고 있습니다', style: TextStyle(color: AppColors.sub)),
          ],
        ),
      ),
    );
  }
}