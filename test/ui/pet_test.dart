import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_app/domain/growth.dart';
import 'package:mm_app/ui/widgets.dart';

void main() {
  test('씨앗부터 왕관까지 단계마다 다른 그림이고 뒤 단계일수록 크다', () {
    final stages = PetStage.values.skip(1).toList();
    final hashes = {for (final s in stages) md5.convert(File(petImage(s)).readAsBytesSync()).toString()};
    expect(hashes.length, stages.length);
    for (var i = 1; i < stages.length; i++) {
      expect(petScale(stages[i]), greaterThanOrEqualTo(petScale(stages[i - 1])), reason: stages[i].name);
    }
    expect(petScale(PetStage.seed), lessThan(petScale(PetStage.crown)));
  });
}
