import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_app/domain/growth.dart';
import 'package:mm_app/ui/widgets.dart';

String hash(String path) => md5.convert(File(path).readAsBytesSync()).toString();

void main() {
  test('씨앗부터 왕관까지 단계마다 다른 그림이고 뒤 단계일수록 크다', () {
    final stages = PetStage.values.skip(1).toList();
    expect({for (final s in stages) hash(petImage(s))}.length, stages.length);
    for (var i = 1; i < stages.length; i++) {
      expect(petScale(stages[i]), greaterThanOrEqualTo(petScale(stages[i - 1])), reason: stages[i].name);
    }
    expect(petScale(PetStage.seed), lessThan(petScale(PetStage.crown)));
  });

  test('목표를 달성할 때마다 왕관이 바뀌고 6번째부터는 마지막 왕관', () {
    final crowns = [for (var n = 1; n <= 6; n++) petImage(PetStage.crown, crowns: n)];
    expect({for (final p in crowns) hash(p)}.length, 6);
    expect(petImage(PetStage.crown, crowns: 9), crowns.last);
    expect(petImage(PetStage.crown, crowns: 0), crowns.first);
    expect(petImage(PetStage.fruit, crowns: 3), petImage(PetStage.fruit));
  });

  test('단계 이름은 계획서대로 꽃과 열매', () {
    expect(PetStage.flower.label, '꽃');
    expect(PetStage.fruit.label, '열매');
  });
}
