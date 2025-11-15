import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:test/test.dart';

void main() {
  group('SpanContext', () {
    test('invalid has all-zero IDs', () {
      expect(SpanContext.invalid.traceId, equals(TraceId.invalid));
      expect(SpanContext.invalid.spanId, equals(SpanId.invalid));
      expect(SpanContext.invalid.isValid, isFalse);
    });

    test('constructor creates valid context', () {
      final traceId = TraceId.random();
      final spanId = SpanId.random();
      final context = SpanContext(traceId: traceId, spanId: spanId);

      expect(context.traceId, equals(traceId));
      expect(context.spanId, equals(spanId));
      expect(context.traceFlags, equals(TraceFlags.none));
      expect(context.traceState, equals(TraceState.empty));
      expect(context.isRemote, isFalse);
    });

    test('constructor accepts all parameters', () {
      final traceId = TraceId.random();
      final spanId = SpanId.random();
      final state = TraceState.empty.put('key', 'value');

      final context = SpanContext(
        traceId: traceId,
        spanId: spanId,
        traceFlags: TraceFlags.sampled,
        traceState: state,
        isRemote: true,
      );

      expect(context.traceFlags, equals(TraceFlags.sampled));
      expect(context.traceState.entries.first.key, equals('key'));
      expect(context.isRemote, isTrue);
    });

    test('isSampled delegates to traceFlags', () {
      final traceId = TraceId.random();
      final spanId = SpanId.random();

      final notSampled = SpanContext(
        traceId: traceId,
        spanId: spanId,
        traceFlags: TraceFlags.none,
      );
      expect(notSampled.isSampled, isFalse);

      final sampled = SpanContext(
        traceId: traceId,
        spanId: spanId,
        traceFlags: TraceFlags.sampled,
      );
      expect(sampled.isSampled, isTrue);
    });

    test('isValid requires both valid traceId and spanId', () {
      final validTraceId = TraceId.random();
      final validSpanId = SpanId.random();

      expect(
        SpanContext(traceId: validTraceId, spanId: validSpanId).isValid,
        isTrue,
      );

      expect(
        SpanContext(traceId: TraceId.invalid, spanId: validSpanId).isValid,
        isFalse,
      );

      expect(
        SpanContext(traceId: validTraceId, spanId: SpanId.invalid).isValid,
        isFalse,
      );

      expect(
        SpanContext(traceId: TraceId.invalid, spanId: SpanId.invalid).isValid,
        isFalse,
      );
    });
  });
}
