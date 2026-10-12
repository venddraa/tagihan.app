import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/domain/entity_id.dart';

void main() {
  group('EntityId', () {
    test('menerima UUIDv7 dan menormalkan huruf menjadi lowercase', () {
      final id = EntityId.fromString('01890F47-3D7A-7C53-BB3C-9D6EC2F1A6B0');

      expect(id.value, '01890f47-3d7a-7c53-bb3c-9d6ec2f1a6b0');
    });

    test('menolak UUID yang bukan versi 7', () {
      expect(
        () => EntityId.fromString('550e8400-e29b-41d4-a716-446655440000'),
        throwsFormatException,
      );
    });

    test('dua ID dengan nilai sama dianggap setara', () {
      final first = EntityId.fromString('01890f47-3d7a-7c53-bb3c-9d6ec2f1a6b0');
      final second = EntityId.fromString(
        '01890f47-3d7a-7c53-bb3c-9d6ec2f1a6b0',
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('membuat UUIDv7 dari waktu dan random client', () {
      final now = DateTime.utc(2026, 10, 12, 9, 30);
      final first = EntityId.generate(now: now, random: Random(1));
      final second = EntityId.generate(now: now, random: Random(2));
      final timestampHex = now.millisecondsSinceEpoch
          .toRadixString(16)
          .padLeft(12, '0');

      expect(first.value.replaceAll('-', '').startsWith(timestampHex), isTrue);
      expect(first.value.substring(14, 15), '7');
      expect('89ab', contains(first.value.substring(19, 20)));
      expect(first, isNot(second));
    });
  });
}
