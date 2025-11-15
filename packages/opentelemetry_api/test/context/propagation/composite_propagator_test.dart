import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:test/test.dart';

class _TestCarrier {
  final Map<String, String> headers = {};
}

class _TestGetter extends TextMapGetter<_TestCarrier> {
  @override
  String? get(_TestCarrier carrier, String key) =>
      carrier.headers[key.toLowerCase()];

  @override
  Iterable<String> keys(_TestCarrier carrier) => carrier.headers.keys;
}

class _TestSetter extends TextMapSetter<_TestCarrier> {
  @override
  void set(_TestCarrier carrier, String key, String value) {
    carrier.headers[key.toLowerCase()] = value;
  }
}

void main() {
  group('CompositeTextMapPropagator', () {
    final getter = _TestGetter();
    final setter = _TestSetter();

    test('fields aggregates all propagator fields', () {
      final propagator = CompositeTextMapPropagator([
        TraceContextPropagator.instance,
        BaggagePropagator.instance,
      ]);

      final fields = propagator.fields.toList();
      expect(fields, contains('traceparent'));
      expect(fields, contains('tracestate'));
      expect(fields, contains('baggage'));
    });

    test('fields deduplicates fields', () {
      final propagator = CompositeTextMapPropagator([
        TraceContextPropagator.instance,
        TraceContextPropagator.instance,
      ]);

      final fields = propagator.fields.toList();
      expect(fields.where((f) => f == 'traceparent').length, equals(1));
    });

    test('inject calls all propagators', () {
      final propagator = CompositeTextMapPropagator([
        TraceContextPropagator.instance,
        BaggagePropagator.instance,
      ]);

      final spanContext = SpanContext(
        traceId: TraceId.fromHex('a' * 32),
        spanId: SpanId.fromHex('b' * 16),
        traceFlags: TraceFlags.sampled,
      );
      final baggage = Baggage.empty.set('key', BaggageEntry('value'));
      final context = Context.root
          .withSpanContext(spanContext)
          .withBaggage(baggage);
      final carrier = _TestCarrier();

      propagator.inject(context, carrier, setter);

      expect(carrier.headers['traceparent'], isNotNull);
      expect(carrier.headers['baggage'], isNotNull);
    });

    test('extract calls all propagators in order', () {
      final propagator = CompositeTextMapPropagator([
        TraceContextPropagator.instance,
        BaggagePropagator.instance,
      ]);

      final carrier = _TestCarrier();
      carrier.headers['traceparent'] = '00-${'a' * 32}-${'b' * 16}-01';
      carrier.headers['baggage'] = 'key=value';

      final context = propagator.extract(Context.root, carrier, getter);

      expect(context.spanContext, isNotNull);
      expect(context.spanContext!.traceId.value, equals('a' * 32));
      expect(context.baggage.toMap()['key']?.value, equals('value'));
    });

    test('extract chains context through propagators', () {
      final propagator = CompositeTextMapPropagator([
        TraceContextPropagator.instance,
        BaggagePropagator.instance,
      ]);

      final carrier = _TestCarrier();
      carrier.headers['traceparent'] = '00-${'a' * 32}-${'b' * 16}-01';
      carrier.headers['baggage'] = 'user=alice';

      final context = propagator.extract(Context.root, carrier, getter);

      // Both should be present in final context
      expect(context.spanContext, isNotNull);
      expect(context.baggage.toMap()['user']?.value, equals('alice'));
    });

    test('roundtrip with multiple propagators', () {
      final propagator = CompositeTextMapPropagator([
        TraceContextPropagator.instance,
        BaggagePropagator.instance,
        B3Propagator(singleHeader: false),
      ]);

      final originalSpanContext = SpanContext(
        traceId: TraceId.fromHex('0123456789abcdef' * 2),
        spanId: SpanId.fromHex('fedcba9876543210'),
        traceFlags: TraceFlags.sampled,
      );
      final originalBaggage = Baggage.empty
          .set('tenant', BaggageEntry('acme'));
      final originalContext = Context.root
          .withSpanContext(originalSpanContext)
          .withBaggage(originalBaggage);

      final carrier = _TestCarrier();
      propagator.inject(originalContext, carrier, setter);

      // Verify all propagators injected
      expect(carrier.headers['traceparent'], isNotNull);
      expect(carrier.headers['baggage'], isNotNull);
      expect(carrier.headers['x-b3-traceid'], isNotNull);

      final extractedContext = propagator.extract(Context.root, carrier, getter);

      expect(
        extractedContext.spanContext!.traceId.value,
        equals(originalSpanContext.traceId.value),
      );
      expect(
        extractedContext.baggage.toMap()['tenant']?.value,
        equals('acme'),
      );
    });

    test('empty composite propagator', () {
      final propagator = CompositeTextMapPropagator([]);

      expect(propagator.fields, isEmpty);

      final carrier = _TestCarrier();
      propagator.inject(Context.root, carrier, setter);
      expect(carrier.headers, isEmpty);

      final context = propagator.extract(Context.root, carrier, getter);
      expect(context, equals(Context.root));
    });

    test('single propagator in composite', () {
      final propagator = CompositeTextMapPropagator([
        BaggagePropagator.instance,
      ]);

      final baggage = Baggage.empty.set('key', BaggageEntry('value'));
      final context = Context.root.withBaggage(baggage);
      final carrier = _TestCarrier();

      propagator.inject(context, carrier, setter);

      expect(carrier.headers['baggage'], isNotNull);
      expect(carrier.headers['traceparent'], isNull);
    });

    test('propagators do not interfere with each other', () {
      final propagator = CompositeTextMapPropagator([
        TraceContextPropagator.instance,
        B3Propagator(singleHeader: true),
      ]);

      final spanContext = SpanContext(
        traceId: TraceId.fromHex('a' * 32),
        spanId: SpanId.fromHex('b' * 16),
        traceFlags: TraceFlags.sampled,
      );
      final context = Context.root.withSpanContext(spanContext);
      final carrier = _TestCarrier();

      propagator.inject(context, carrier, setter);

      // Both formats should be present
      expect(carrier.headers['traceparent'], contains('00-'));
      expect(carrier.headers['b3'], contains('-1'));

      // Extract should get the same data from either
      final extractedContext = propagator.extract(Context.root, carrier, getter);
      expect(
        extractedContext.spanContext!.traceId.value,
        equals(spanContext.traceId.value),
      );
    });
  });
}
