import 'package:flutter_test/flutter_test.dart';
import 'package:mm_app/data/app_model.dart';
import 'package:mm_app/data/store.dart';
import 'package:mm_app/domain/rag.dart';
import 'package:mm_app/services/ai_service.dart';
import 'package:mm_app/ui/widgets.dart' show errorDetail;

const doc = Knowledge(id: 'd1', kind: 'basics', title: '예금자보호', body: 'b', url: 'https://e.kr', source: 's', checkedAt: 'd');
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final m = AppModel(MemoryStore());
  test('지어낸 출처 id 는 버린다', () => expect(AiService.parse('{"answer":"답","ids":["없는id"]}', [doc], mine: false), isNull));
  test('출처가 맞으면 통과', () => expect(AiService.parse('{"answer":"답","ids":["d1"]}', [doc], mine: false)!.sources.single.id, 'd1'));
  test('JSON 이 아니면 버린다', () => expect(AiService.parse('그냥 글', [doc], mine: true), isNull));
  test('매매 권유는 버린다', () => expect(AiService.parse('{"answer":"하이닉스를 매수하세요","ids":["d1"]}', [doc], mine: false), isNull));
  test('근거가 없으면 모델을 부르지도 않는다', () async {
    var calls = 0;
    final a = await AiService(generate: (_) async { calls++; return ''; }).ask('오늘 점심 메뉴 뭐가 좋아', m);
    expect(a.text, noEvidence);
    expect(calls, 0);
  });
  test('한도에 걸려도 저장된 자료와 출처로 답한다', () async {
    final a = await AiService(generate: (_) async => throw Exception('quota')).ask('예금자보호 한도가 얼마야', m);
    expect(a.byModel, isFalse);
    expect(a.sources, isNotEmpty);
    expect(a.notice, contains('한도'));
    expect(a.detail, contains('quota'));
  });
  test('같은 질문은 한 번만 부른다', () async {
    var calls = 0;
    final s = AiService(generate: (_) async { calls++; return '{"answer":"아직 남았어요","ids":[]}'; });
    await s.ask('오늘 생활비 얼마 남았어', m);
    await s.ask('오늘 생활비 얼마 남았어', m);
    expect(calls, 1);
  });
  test('이름과 결제 원문은 프롬프트에 없다', () async {
    var sent = '';
    await AiService(generate: (p) async { sent = p; return '{"answer":"답","ids":[]}'; }).ask('내 지출 어때', m..name = '홍길동');
    expect(sent, isNot(contains('홍길동')));
  });
  test('에러 원문의 긴 토큰은 가린다', () {
    expect(errorDetail(Exception('bad token 9E7D6FAD9E7D6FAD9E7D6FAD9E7D6FADXX x')), 'Exception: bad token … x');
  });
}
