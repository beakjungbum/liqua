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

  test('왕관은 달성한 목표 수로 랭크가 오른다', () {
    expect([for (var n = 1; n <= 6; n++) crownRank(n).label],
        ['토이 크라운', '브론즈 크라운', '플래티넘 크라운', '다이아 크라운', '루비 크라운', '임페리얼 크라운']);
    expect(crownRank(0), CrownRank.toy);
    expect(crownRank(20), CrownRank.imperial);
    expect(petTitle(PetStage.crown, 3), '플래티넘 크라운');
    expect(petTitle(PetStage.flower, 3), '꽃 단계');
    expect(petNext(PetStage.crown, 1), '목표를 하나 더 달성하면 브론즈 크라운이 돼요');
    expect(petNext(PetStage.crown, 6), '최고 랭크, 임페리얼 크라운이에요');
    expect(petNext(PetStage.fruit, 0), PetStage.fruit.next);
  });

  test('랭크마다 그림이 다르다', () {
    expect({for (final r in CrownRank.values) hash(crownImage(r))}.length, CrownRank.values.length);
    expect(petImage(PetStage.crown, crowns: 4), crownImage(CrownRank.diamond));
  });
}
