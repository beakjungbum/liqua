import 'package:firebase_ai/firebase_ai.dart';
import 'package:mm_app/services/asset_service.dart';
import 'package:mm_app/services/auth_service.dart';

class ChatLine {
  const ChatLine({
    required this.text,
    required this.fromUser,
    this.includedSummary = false,
  });

  final String text;
  final bool fromUser;
  final bool includedSummary;
}

class ChatService {
  ChatService._() {
    AuthService.instance.authStateChanges().listen((user) {
      if (user == null) messages.clear();
    });
  }

  static final ChatService instance = ChatService._();

  /// 무료 등급 모델을 바꿀 때는 이 값만 수정한다.
  static const modelName = 'gemini-3.5-flash-lite';

  static const _instructions = '''
너는 교육용 자산 기록 보조 앱의 챗봇이다.
짧고 쉬운 한국어로 답한다.
특정 종목을 매수하거나 매도하라고 단정하지 않는다.
수익을 보장한다고 말하지 않는다.
실제 주가 데이터에 접근할 수 없으므로 현재 시세를 아는 것처럼 말하지 않는다.
자산 이름, 메모, 이메일은 주어지지 않는다.
질문에 총 자산, 목표 금액, 달성률 숫자가 함께 있으면 그 숫자만 참고한다.
지금 받은 질문만 보고 답한다.
''';

  final List<ChatLine> messages = <ChatLine>[];

  static bool includesProgressSummary(String question) {
    final compact = question.replaceAll(' ', '');
    return compact.contains('목표') ||
        compact.contains('달성') ||
        compact.contains('총자산');
  }

  Future<String> ask(String question) async {
    final text = question.trim();
    if (text.isEmpty) {
      throw ArgumentError('질문을 입력하세요.');
    }
    final summary = includesProgressSummary(text)
        ? await _progressSummary()
        : null;
    final prompt = summary == null ? text : '$text\n$summary';
    final model = FirebaseAI.googleAI().generativeModel(
      model: modelName,
      systemInstruction: Content.system(_instructions),
      generationConfig: GenerationConfig(maxOutputTokens: 256),
    );
    final response = await model.generateContent([Content.text(prompt)]);
    final answer = response.text?.trim() ?? '';
    if (answer.isEmpty) {
      throw StateError('응답이 없습니다.');
    }
    return answer;
  }

  Future<String> _progressSummary() async {
    final total = await AssetService.instance.totalValuation();
    final progress = await AuthService.instance.currentProgress();
    final rate = achievementPercent(total, progress.targetAmount).round();
    return '참고 수치만 전달됨. 총 자산 ${total.round()}원, 목표 금액 ${progress.targetAmount}원, 달성률 $rate%.';
  }
}

String messageForChatError(Object error) {
  if (error is QuotaExceeded) {
    return '사용량 한도에 도달했습니다. 잠시 후 다시 시도하세요.';
  }
  if (error is ArgumentError) {
    return error.message?.toString() ?? '질문을 입력하세요.';
  }
  if (error is StateError && error.message == '응답이 없습니다.') {
    return '응답이 없습니다.';
  }
  final raw = error.toString().toLowerCase();
  if (raw.contains('app check') || raw.contains('appcheck')) {
    return 'App Check 확인에 실패했습니다. 디버그 토큰 등록을 확인하세요.';
  }
  if (raw.contains('permission-denied') || raw.contains('permission_denied')) {
    return '이 데이터에 접근할 권한이 없습니다. 로그인 상태와 Firestore 규칙을 확인하세요.';
  }
  if (raw.contains('network') ||
      raw.contains('socket') ||
      raw.contains('failed host lookup') ||
      raw.contains('connection') ||
      raw.contains('unavailable') ||
      raw.contains('timed out')) {
    return '네트워크 오류입니다. 인터넷 연결을 확인하세요.';
  }
  return '답변을 받지 못했습니다.';
}