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
  final getter = _TestGetter();
  final setter = _TestSetter();

  group('B3Propagator - Multi-Header', () {
    final propagator = B3Propagator(singleHeader: false);

    test('fields includes multi-header names', () {
      expect(
        propagator.fields,
        containsAll(['x-b3-traceid', 'x-b3-spanid', 'x-b3-sampled']),
      );
    });

    test('inject adds B3 headers', () {
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

      expect(carrier.headers['x-b3-traceid'], equals('a' * 32));
      expect(carrier.headers['x-b3-spanid'], equals('b' * 16));
      expect(carrier.headers['x-b3-sampled'], equals('1'));
    });

    test('inject sampled=0 when not sampled', () {
      final spanContext = SpanContext(
        traceId: TraceId.fromHex('a' * 32),
        spanId: SpanId.fromHex('b' * 16),
        traceFlags: TraceFlags.none,
      );
      final context = Context.root.withSpanContext(spanContext);
      final carrier = _TestCarrier();

      propagator.inject(context, carrier, setter);

      expect(carrier.headers['x-b3-sampled'], equals('0'));
    });

    test('inject does nothing for invalid context', () {
      final context = Context.root.withSpanContext(SpanContext.invalid);
      final carrier = _TestCarrier();

      propagator.inject(context, carrier, setter);

      expect(carrier.headers, isEmpty);
    });

    test('extract parses B3 headers', () {
      final carrier = _TestCarrier();
      carrier.headers['x-b3-traceid'] = 'a' * 32;
      carrier.headers['x-b3-spanid'] = 'b' * 16;
      carrier.headers['x-b3-sampled'] = '1';

      final context = propagator.extract(Context.root, carrier, getter);
      final spanContext = context.spanContext;

      expect(spanContext, isNotNull);
      expect(spanContext!.traceId.value, equals('a' * 32));
      expect(spanContext.spanId.value, equals('b' * 16));
      expect(spanContext.isSampled, isTrue);
      expect(spanContext.isRemote, isTrue);
    });

    test('extract handles short trace IDs with padding', () {
      final carrier = _TestCarrier();
      carrier.headers['x-b3-traceid'] = 'abc123';
      carrier.headers['x-b3-spanid'] = 'def456';
      carrier.headers['x-b3-sampled'] = '0';

      final context = propagator.extract(Context.root, carrier, getter);
      final spanContext = context.spanContext;

      expect(spanContext!.traceId.value, equals('0' * 26 + 'abc123'));
      expect(spanContext.spanId.value, equals('0' * 10 + 'def456'));
      expect(spanContext.isSampled, isFalse);
    });

    test('extract returns original context when missing traceId', () {
      final carrier = _TestCarrier();
      carrier.headers['x-b3-spanid'] = 'b' * 16;

      final context = propagator.extract(Context.root, carrier, getter);

      expect(context, equals(Context.root));
    });

    test('extract returns original context when missing spanId', () {
      final carrier = _TestCarrier();
      carrier.headers['x-b3-traceid'] = 'a' * 32;

      final context = propagator.extract(Context.root, carrier, getter);

      expect(context, equals(Context.root));
    });

    test('extract defaults to not sampled when sampled header missing', () {
      final carrier = _TestCarrier();
      carrier.headers['x-b3-traceid'] = 'a' * 32;
      carrier.headers['x-b3-spanid'] = 'b' * 16;

      final context = propagator.extract(Context.root, carrier, getter);
      final spanContext = context.spanContext;

      expect(spanContext!.isSampled, isFalse);
    });

    test('roundtrip preserves context', () {
      final originalSpanContext = SpanContext(
        traceId: TraceId.fromHex('0123456789abcdef' * 2),
        spanId: SpanId.fromHex('fedcba9876543210'),
        traceFlags: TraceFlags.sampled,
      );
      final originalContext = Context.root.withSpanContext(originalSpanContext);

      final carrier = _TestCarrier();
      propagator.inject(originalContext, carrier, setter);

      final extractedContext = propagator.extract(Context.root, carrier, getter);
      final extractedSpanContext = extractedContext.spanContext;

      expect(
        extractedSpanContext!.traceId.value,
        equals(originalSpanContext.traceId.value),
      );
      expect(
        extractedSpanContext.spanId.value,
        equals(originalSpanContext.spanId.value),
      );
      expect(
        extractedSpanContext.isSampled,
        equals(originalSpanContext.isSampled),
      );
    });
  });

  group('B3Propagator - Single Header', () {
    final propagator = B3Propagator(singleHeader: true);

    test('fields includes single header name', () {
      expect(propagator.fields, contains('b3'));
      expect(propagator.fields.length, equals(1));
    });

    test('inject adds single B3 header', () {
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
        carrier.headers['b3'],
        equals('${'a' * 32}-${'b' * 16}-1'),
      );
    });

    test('inject single header with sampled=0', () {
      final spanContext = SpanContext(
        traceId: TraceId.fromHex('a' * 32),
        spanId: SpanId.fromHex('b' * 16),
        traceFlags: TraceFlags.none,
      );
      final context = Context.root.withSpanContext(spanContext);
      final carrier = _TestCarrier();

      propagator.inject(context, carrier, setter);

      expect(
        carrier.headers['b3'],
        equals('${'a' * 32}-${'b' * 16}-0'),
      );
    });

    test('extract parses single B3 header', () {
      final carrier = _TestCarrier();
      carrier.headers['b3'] = '${'a' * 32}-${'b' * 16}-1';

      final context = propagator.extract(Context.root, carrier, getter);
      final spanContext = context.spanContext;

      expect(spanContext!.traceId.value, equals('a' * 32));
      expect(spanContext.spanId.value, equals('b' * 16));
      expect(spanContext.isSampled, isTrue);
    });

    test('extract single header without sampled flag', () {
      final carrier = _TestCarrier();
      carrier.headers['b3'] = '${'a' * 32}-${'b' * 16}';

      final context = propagator.extract(Context.root, carrier, getter);
      final spanContext = context.spanContext;

      expect(spanContext!.traceId.value, equals('a' * 32));
      expect(spanContext.spanId.value, equals('b' * 16));
      expect(spanContext.isSampled, isFalse);
    });

    test('extract handles true as sampled flag', () {
      final carrier = _TestCarrier();
      carrier.headers['b3'] = '${'a' * 32}-${'b' * 16}-true';

      final context = propagator.extract(Context.root, carrier, getter);
      final spanContext = context.spanContext;

      expect(spanContext!.isSampled, isTrue);
    });

    test('extract handles short IDs with padding in single header', () {
      final carrier = _TestCarrier();
      carrier.headers['b3'] = 'abc123-def456-1';

      final context = propagator.extract(Context.root, carrier, getter);
      final spanContext = context.spanContext;

      expect(spanContext!.traceId.value, equals('0' * 26 + 'abc123'));
      expect(spanContext.spanId.value, equals('0' * 10 + 'def456'));
    });

    test('extract returns original context for malformed single header', () {
      final carrier = _TestCarrier();
      carrier.headers['b3'] = 'invalid';

      final context = propagator.extract(Context.root, carrier, getter);

      expect(context, equals(Context.root));
    });

    test('roundtrip preserves context with single header', () {
      final originalSpanContext = SpanContext(
        traceId: TraceId.fromHex('0123456789abcdef' * 2),
        spanId: SpanId.fromHex('fedcba9876543210'),
        traceFlags: TraceFlags.sampled,
      );
      final originalContext = Context.root.withSpanContext(originalSpanContext);

      final carrier = _TestCarrier();
      propagator.inject(originalContext, carrier, setter);

      final extractedContext = propagator.extract(Context.root, carrier, getter);
      final extractedSpanContext = extractedContext.spanContext;

      expect(
        extractedSpanContext!.traceId.value,
        equals(originalSpanContext.traceId.value),
      );
      expect(
        extractedSpanContext.spanId.value,
        equals(originalSpanContext.spanId.value),
      );
      expect(
        extractedSpanContext.isSampled,
        equals(originalSpanContext.isSampled),
      );
    });
  });
}
