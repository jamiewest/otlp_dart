import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:test/test.dart';

void main() {
  group('SpanId', () {
    test('invalid SpanId should be all zeros', () {
      expect(SpanId.invalid.value, equals('0' * 16));
      expect(SpanId.invalid.isValid, isFalse);
    });

    test('fromHex creates valid SpanId from 16 hex chars', () {
      final hex = 'a' * 16;
      final spanId = SpanId.fromHex(hex);
      expect(spanId.value, equals(hex));
      expect(spanId.isValid, isTrue);
    });

    test('fromHex converts to lowercase', () {
      final spanId = SpanId.fromHex('ABCDEF01' * 2);
      expect(spanId.value, equals('abcdef01' * 2));
    });

    test('fromHex throws on invalid length', () {
      expect(() => SpanId.fromHex('abc'), throwsArgumentError);
      expect(() => SpanId.fromHex('a' * 15), throwsArgumentError);
      expect(() => SpanId.fromHex('a' * 17), throwsArgumentError);
    });

    test('random generates valid SpanId', () {
      final spanId = SpanId.random();
      expect(spanId.value.length, equals(16));
      expect(spanId.isValid, isTrue);
    });

    test('random generates different values', () {
      final id1 = SpanId.random();
      final id2 = SpanId.random();
      expect(id1.value, isNot(equals(id2.value)));
    });

    test('random generates only hex characters', () {
      final spanId = SpanId.random();
      final hexPattern = RegExp(r'^[0-9a-f]{16}$');
      expect(hexPattern.hasMatch(spanId.value), isTrue);
    });

    test('toString returns value', () {
      final hex = '0123456789abcdef';
      final spanId = SpanId.fromHex(hex);
      expect(spanId.toString(), equals(hex));
    });

    test('isValid returns false only for all-zeros', () {
      expect(SpanId.fromHex('0' * 16).isValid, isFalse);
      expect(SpanId.fromHex('0' * 15 + '1').isValid, isTrue);
      expect(SpanId.fromHex('1' + '0' * 15).isValid, isTrue);
    });
  });
}
