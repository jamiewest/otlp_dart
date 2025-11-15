import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:test/test.dart';

void main() {
  group('TraceId', () {
    test('invalid TraceId should be all zeros', () {
      expect(TraceId.invalid.value, equals('0' * 32));
      expect(TraceId.invalid.isValid, isFalse);
    });

    test('fromHex creates valid TraceId from 32 hex chars', () {
      final hex = 'a' * 32;
      final traceId = TraceId.fromHex(hex);
      expect(traceId.value, equals(hex));
      expect(traceId.isValid, isTrue);
    });

    test('fromHex converts to lowercase', () {
      final traceId = TraceId.fromHex('ABCDEF01' * 4);
      expect(traceId.value, equals('abcdef01' * 4));
    });

    test('fromHex throws on invalid length', () {
      expect(() => TraceId.fromHex('abc'), throwsArgumentError);
      expect(() => TraceId.fromHex('a' * 31), throwsArgumentError);
      expect(() => TraceId.fromHex('a' * 33), throwsArgumentError);
    });

    test('random generates valid TraceId', () {
      final traceId = TraceId.random();
      expect(traceId.value.length, equals(32));
      expect(traceId.isValid, isTrue);
    });

    test('random generates different values', () {
      final id1 = TraceId.random();
      final id2 = TraceId.random();
      expect(id1.value, isNot(equals(id2.value)));
    });

    test('random generates only hex characters', () {
      final traceId = TraceId.random();
      final hexPattern = RegExp(r'^[0-9a-f]{32}$');
      expect(hexPattern.hasMatch(traceId.value), isTrue);
    });

    test('toString returns value', () {
      final hex = '0123456789abcdef' * 2;
      final traceId = TraceId.fromHex(hex);
      expect(traceId.toString(), equals(hex));
    });

    test('isValid returns false only for all-zeros', () {
      expect(TraceId.fromHex('0' * 32).isValid, isFalse);
      expect(TraceId.fromHex('0' * 31 + '1').isValid, isTrue);
      expect(TraceId.fromHex('1' + '0' * 31).isValid, isTrue);
    });
  });
}
