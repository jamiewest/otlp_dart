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
  group('TraceContextPropagator', () {
    final propagator = TraceContextPropagator.instance;
    final getter = _TestGetter();
    final setter = _TestSetter();

    test('fields includes traceparent and tracestate', () {
      expect(propagator.fields, containsAll(['traceparent', 'tracestate']));
    });

    test('inject adds traceparent header', () {
      final traceId = TraceId.fromHex('a' * 32);
      final spanId = SpanId.fromHex('b' * 16);
      final spanContext = SpanContext(
        traceId: traceId,
        spanId: spanId,
        traceFlags: TraceFlags.sampled,
      );
      final context = Context.root.withSpanContext(spanContext);
      final carrier = _TestCarrier();

      propagator.inject(context, carrier, setter);

      expect(
        carrier.headers['traceparent'],
        equals('00-${'a' * 32}-${'b' * 16}-01'),
      );
    });

    test('inject adds tracestate when present', () {
      final traceId = TraceId.fromHex('a' * 32);
      final spanId = SpanId.fromHex('b' * 16);
      final traceState = TraceState.empty.put('vendor', 'value');
      final spanContext = SpanContext(
        traceId: traceId,
        spanId: spanId,
        traceState: traceState,
      );
      final context = Context.root.withSpanContext(spanContext);
      final carrier = _TestCarrier();

      propagator.inject(context, carrier, setter);

      expect(carrier.headers['tracestate'], equals('vendor=value'));
    });

    test('inject adds multiple tracestate entries', () {
      final traceId = TraceId.fromHex('a' * 32);
      final spanId = SpanId.fromHex('b' * 16);
      final traceState = TraceState.empty
          .put('vendor1', 'value1')
          .put('vendor2', 'value2');
      final spanContext = SpanContext(
        traceId: traceId,
        spanId: spanId,
        traceState: traceState,
      );
      final context = Context.root.withSpanContext(spanContext);
      final carrier = _TestCarrier();

      propagator.inject(context, carrier, setter);

      expect(carrier.headers['tracestate'], equals('vendor2=value2,vendor1=value1'));
    });

    test('inject does nothing for invalid context', () {
      final context = Context.root.withSpanContext(SpanContext.invalid);
      final carrier = _TestCarrier();

      propagator.inject(context, carrier, setter);

      expect(carrier.headers, isEmpty);
    });

    test('inject does nothing when no span context', () {
      final carrier = _TestCarrier();

      propagator.inject(Context.root, carrier, setter);

      expect(carrier.headers, isEmpty);
    });

    test('extract parses valid traceparent', () {
      final carrier = _TestCarrier();
      carrier.headers['traceparent'] =
          '00-${'a' * 32}-${'b' * 16}-01';

      final context = propagator.extract(Context.root, carrier, getter);
      final spanContext = context.spanContext;

      expect(spanContext, isNotNull);
      expect(spanContext!.traceId.value, equals('a' * 32));
      expect(spanContext.spanId.value, equals('b' * 16));
      expect(spanContext.traceFlags.value, equals(1));
      expect(spanContext.isSampled, isTrue);
      expect(spanContext.isRemote, isTrue);
    });

    test('extract parses tracestate', () {
      final carrier = _TestCarrier();
      carrier.headers['traceparent'] =
          '00-${'a' * 32}-${'b' * 16}-00';
      carrier.headers['tracestate'] = 'vendor=value';

      final context = propagator.extract(Context.root, carrier, getter);
      final spanContext = context.spanContext;

      expect(spanContext!.traceState.entries.length, equals(1));
      expect(spanContext.traceState.entries.first.key, equals('vendor'));
      expect(spanContext.traceState.entries.first.value, equals('value'));
    });

    test('extract parses multiple tracestate entries', () {
      final carrier = _TestCarrier();
      carrier.headers['traceparent'] =
          '00-${'a' * 32}-${'b' * 16}-00';
      carrier.headers['tracestate'] = 'vendor1=value1,vendor2=value2';

      final context = propagator.extract(Context.root, carrier, getter);
      final spanContext = context.spanContext;

      expect(spanContext!.traceState.entries.length, equals(2));
      expect(spanContext.traceState.entries[0].key, equals('vendor1'));
      expect(spanContext.traceState.entries[1].key, equals('vendor2'));
    });

    test('extract handles whitespace in tracestate', () {
      final carrier = _TestCarrier();
      carrier.headers['traceparent'] =
          '00-${'a' * 32}-${'b' * 16}-00';
      carrier.headers['tracestate'] = 'vendor1=value1 , vendor2=value2';

      final context = propagator.extract(Context.root, carrier, getter);
      final spanContext = context.spanContext;

      expect(spanContext!.traceState.entries.length, equals(2));
    });

    test('extract returns original context when no traceparent', () {
      final carrier = _TestCarrier();
      final context = propagator.extract(Context.root, carrier, getter);

      expect(context, equals(Context.root));
    });

    test('extract returns original context for malformed traceparent', () {
      final carrier = _TestCarrier();
      carrier.headers['traceparent'] = 'invalid';

      final context = propagator.extract(Context.root, carrier, getter);

      expect(context, equals(Context.root));
    });

    test('extract handles traceparent with non-sampled flag', () {
      final carrier = _TestCarrier();
      carrier.headers['traceparent'] =
          '00-${'a' * 32}-${'b' * 16}-00';

      final context = propagator.extract(Context.root, carrier, getter);
      final spanContext = context.spanContext;

      expect(spanContext!.isSampled, isFalse);
    });

    test('roundtrip preserves context', () {
      final originalTraceId = TraceId.fromHex('0123456789abcdef' * 2);
      final originalSpanId = SpanId.fromHex('fedcba9876543210');
      final originalTraceState = TraceState.empty
          .put('vendor1', 'value1')
          .put('vendor2', 'value2');
      final originalSpanContext = SpanContext(
        traceId: originalTraceId,
        spanId: originalSpanId,
        traceFlags: TraceFlags.sampled,
        traceState: originalTraceState,
      );
      final originalContext = Context.root.withSpanContext(originalSpanContext);

      // Inject
      final carrier = _TestCarrier();
      propagator.inject(originalContext, carrier, setter);

      // Extract
      final extractedContext = propagator.extract(Context.root, carrier, getter);
      final extractedSpanContext = extractedContext.spanContext;

      expect(extractedSpanContext!.traceId.value, equals(originalTraceId.value));
      expect(extractedSpanContext.spanId.value, equals(originalSpanId.value));
      expect(extractedSpanContext.isSampled, equals(originalSpanContext.isSampled));
      expect(extractedSpanContext.traceState.entries.length, equals(2));
    });

    test('extract ignores invalid tracestate entries', () {
      final carrier = _TestCarrier();
      carrier.headers['traceparent'] =
          '00-${'a' * 32}-${'b' * 16}-00';
      carrier.headers['tracestate'] = 'valid=value,invalid,=nokey,novalue=';

      final context = propagator.extract(Context.root, carrier, getter);
      final spanContext = context.spanContext;

      // Should only have the valid entry
      expect(spanContext!.traceState.entries.length, equals(1));
      expect(spanContext.traceState.entries.first.key, equals('valid'));
    });
  });
}
