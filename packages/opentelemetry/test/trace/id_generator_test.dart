import 'package:opentelemetry/opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('RandomIdGenerator', () {
    final generator = RandomIdGenerator();

    test('newTraceId generates valid TraceId', () {
      final traceId = generator.newTraceId();

      expect(traceId.isValid, isTrue);
      expect(traceId.value.length, equals(32));
    });

    test('newSpanId generates valid SpanId', () {
      final spanId = generator.newSpanId();

      expect(spanId.isValid, isTrue);
      expect(spanId.value.length, equals(16));
    });

    test('newTraceId generates different IDs', () {
      final id1 = generator.newTraceId();
      final id2 = generator.newTraceId();

      expect(id1.value, isNot(equals(id2.value)));
    });

    test('newSpanId generates different IDs', () {
      final id1 = generator.newSpanId();
      final id2 = generator.newSpanId();

      expect(id1.value, isNot(equals(id2.value)));
    });

    test('newTraceId generates only hex characters', () {
      final traceId = generator.newTraceId();
      final hexPattern = RegExp(r'^[0-9a-f]{32}$');

      expect(hexPattern.hasMatch(traceId.value), isTrue);
    });

    test('newSpanId generates only hex characters', () {
      final spanId = generator.newSpanId();
      final hexPattern = RegExp(r'^[0-9a-f]{16}$');

      expect(hexPattern.hasMatch(spanId.value), isTrue);
    });

    test('generates multiple unique trace IDs', () {
      final ids = <String>{};
      for (var i = 0; i < 100; i++) {
        ids.add(generator.newTraceId().value);
      }

      expect(ids.length, equals(100)); // All unique
    });

    test('generates multiple unique span IDs', () {
      final ids = <String>{};
      for (var i = 0; i < 100; i++) {
        ids.add(generator.newSpanId().value);
      }

      expect(ids.length, equals(100)); // All unique
    });

    test('const constructor allows singleton usage', () {
      const gen1 = RandomIdGenerator();
      const gen2 = RandomIdGenerator();

      expect(identical(gen1, gen2), isTrue);
    });
  });
}
