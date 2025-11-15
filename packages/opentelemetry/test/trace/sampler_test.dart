import 'package:opentelemetry/opentelemetry.dart';
import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:test/test.dart';

void main() {
  group('AlwaysOnSampler', () {
    test('description', () {
      final sampler = AlwaysOnSampler();
      expect(sampler.description, equals('AlwaysOnSampler'));
    });

    test('should sample all spans', () {
      final sampler = AlwaysOnSampler();
      final options = SamplingOptions(
        parentContext: Context.root,
        traceId: TraceId.random(),
        spanName: 'test-span',
        spanKind: SpanKind.internal,
      );

      final result = sampler.shouldSample(options);

      expect(result.decision, equals(SamplingDecision.recordAndSample));
      expect(result.isSampled, isTrue);
    });
  });

  group('AlwaysOffSampler', () {
    test('description', () {
      final sampler = AlwaysOffSampler();
      expect(sampler.description, equals('AlwaysOffSampler'));
    });

    test('should drop all spans', () {
      final sampler = AlwaysOffSampler();
      final options = SamplingOptions(
        parentContext: Context.root,
        traceId: TraceId.random(),
        spanName: 'test-span',
        spanKind: SpanKind.internal,
      );

      final result = sampler.shouldSample(options);

      expect(result.decision, equals(SamplingDecision.drop));
      expect(result.isSampled, isFalse);
    });
  });

  group('TraceIdRatioBasedSampler', () {
    test('description includes probability', () {
      final sampler = TraceIdRatioBasedSampler(0.5);
      expect(sampler.description, contains('0.5'));
    });

    test('probability 0 drops all spans', () {
      final sampler = TraceIdRatioBasedSampler(0.0);
      final options = SamplingOptions(
        parentContext: Context.root,
        traceId: TraceId.fromHex('f' * 32),
        spanName: 'test-span',
        spanKind: SpanKind.internal,
      );

      final result = sampler.shouldSample(options);

      expect(result.decision, equals(SamplingDecision.drop));
      expect(result.isSampled, isFalse);
    });

    test('probability 1 samples all spans', () {
      final sampler = TraceIdRatioBasedSampler(1.0);
      final options = SamplingOptions(
        parentContext: Context.root,
        traceId: TraceId.fromHex('0' * 32),
        spanName: 'test-span',
        spanKind: SpanKind.internal,
      );

      final result = sampler.shouldSample(options);

      expect(result.decision, equals(SamplingDecision.recordAndSample));
      expect(result.isSampled, isTrue);
    });

    test('probability 0.5 samples approximately half', () {
      final sampler = TraceIdRatioBasedSampler(0.5);
      var sampledCount = 0;
      final iterations = 1000;

      for (var i = 0; i < iterations; i++) {
        final options = SamplingOptions(
          parentContext: Context.root,
          traceId: TraceId.random(),
          spanName: 'test-span',
          spanKind: SpanKind.internal,
        );

        final result = sampler.shouldSample(options);
        if (result.isSampled) {
          sampledCount++;
        }
      }

      // Allow for some variance, but should be roughly 50%
      expect(sampledCount, greaterThan(400));
      expect(sampledCount, lessThan(600));
    });

    test('samples low trace IDs consistently with low probability', () {
      final sampler = TraceIdRatioBasedSampler(0.0001);
      final lowTraceId = TraceId.fromHex('0' * 31 + '1');
      final highTraceId = TraceId.fromHex('f' * 32);

      final lowResult = sampler.shouldSample(SamplingOptions(
        parentContext: Context.root,
        traceId: lowTraceId,
        spanName: 'test',
        spanKind: SpanKind.internal,
      ));

      final highResult = sampler.shouldSample(SamplingOptions(
        parentContext: Context.root,
        traceId: highTraceId,
        spanName: 'test',
        spanKind: SpanKind.internal,
      ));

      expect(lowResult.isSampled, isTrue);
      expect(highResult.isSampled, isFalse);
    });

    test('throws on invalid probability', () {
      expect(() => TraceIdRatioBasedSampler(-0.1), throwsA(isA<AssertionError>()));
      expect(() => TraceIdRatioBasedSampler(1.1), throwsA(isA<AssertionError>()));
    });

    test('sampling decision is deterministic', () {
      final sampler = TraceIdRatioBasedSampler(0.5);
      final traceId = TraceId.random();
      final options = SamplingOptions(
        parentContext: Context.root,
        traceId: traceId,
        spanName: 'test-span',
        spanKind: SpanKind.internal,
      );

      final result1 = sampler.shouldSample(options);
      final result2 = sampler.shouldSample(options);

      expect(result1.decision, equals(result2.decision));
    });
  });

  group('SamplingResult', () {
    test('isSampled true for recordAndSample', () {
      final result = SamplingResult(SamplingDecision.recordAndSample);
      expect(result.isSampled, isTrue);
    });

    test('isSampled false for recordOnly', () {
      final result = SamplingResult(SamplingDecision.recordOnly);
      expect(result.isSampled, isFalse);
    });

    test('isSampled false for drop', () {
      final result = SamplingResult(SamplingDecision.drop);
      expect(result.isSampled, isFalse);
    });

    test('accepts attributes and traceState', () {
      final traceState = TraceState.empty.put('vendor', 'value');
      final result = SamplingResult(
        SamplingDecision.recordAndSample,
        attributes: {'key': 'value'},
        traceState: traceState,
      );

      expect(result.attributes['key'], equals('value'));
      expect(result.traceState, equals(traceState));
    });
  });
}
