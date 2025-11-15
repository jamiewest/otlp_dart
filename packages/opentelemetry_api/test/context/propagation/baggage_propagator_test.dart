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
  group('BaggagePropagator', () {
    final propagator = BaggagePropagator.instance;
    final getter = _TestGetter();
    final setter = _TestSetter();

    test('fields includes baggage header', () {
      expect(propagator.fields, contains('baggage'));
    });

    test('inject adds baggage header', () {
      final baggage = Baggage.empty
          .set('key1', BaggageEntry('value1'))
          .set('key2', BaggageEntry('value2'));
      final context = Context.root.withBaggage(baggage);
      final carrier = _TestCarrier();

      propagator.inject(context, carrier, setter);

      final header = carrier.headers['baggage'];
      expect(header, isNotNull);
      expect(header, contains('key1=value1'));
      expect(header, contains('key2=value2'));
    });

    test('inject does nothing for empty baggage', () {
      final context = Context.root.withBaggage(Baggage.empty);
      final carrier = _TestCarrier();

      propagator.inject(context, carrier, setter);

      expect(carrier.headers, isEmpty);
    });

    test('inject does nothing when no baggage in context', () {
      final carrier = _TestCarrier();

      propagator.inject(Context.root, carrier, setter);

      expect(carrier.headers, isEmpty);
    });

    test('inject URL-encodes special characters', () {
      final baggage = Baggage.empty
          .set('key', BaggageEntry('value with spaces'));
      final context = Context.root.withBaggage(baggage);
      final carrier = _TestCarrier();

      propagator.inject(context, carrier, setter);

      expect(carrier.headers['baggage'], equals('key=value%20with%20spaces'));
    });

    test('extract parses baggage header', () {
      final carrier = _TestCarrier();
      carrier.headers['baggage'] = 'key1=value1,key2=value2';

      final context = propagator.extract(Context.root, carrier, getter);
      final baggage = context.baggage;

      expect(baggage.toMap()['key1']?.value, equals('value1'));
      expect(baggage.toMap()['key2']?.value, equals('value2'));
    });

    test('extract URL-decodes values', () {
      final carrier = _TestCarrier();
      carrier.headers['baggage'] = 'key=value%20with%20spaces';

      final context = propagator.extract(Context.root, carrier, getter);
      final baggage = context.baggage;

      expect(baggage.toMap()['key']?.value, equals('value with spaces'));
    });

    test('extract handles whitespace', () {
      final carrier = _TestCarrier();
      carrier.headers['baggage'] = 'key1=value1 , key2=value2';

      final context = propagator.extract(Context.root, carrier, getter);
      final baggage = context.baggage;

      expect(baggage.toMap()['key1']?.value, equals('value1'));
      expect(baggage.toMap()['key2']?.value, equals('value2'));
    });

    test('extract returns original context when no baggage header', () {
      final carrier = _TestCarrier();

      final context = propagator.extract(Context.root, carrier, getter);

      expect(context, equals(Context.root));
    });

    test('extract returns original context for empty header', () {
      final carrier = _TestCarrier();
      carrier.headers['baggage'] = '';

      final context = propagator.extract(Context.root, carrier, getter);

      expect(context, equals(Context.root));
    });

    test('extract ignores malformed entries', () {
      final carrier = _TestCarrier();
      carrier.headers['baggage'] = 'valid=value,invalid,=nokey,novalue=,good=data';

      final context = propagator.extract(Context.root, carrier, getter);
      final baggage = context.baggage;

      expect(baggage.toMap()['valid']?.value, equals('value'));
      expect(baggage.toMap()['good']?.value, equals('data'));
      expect(baggage.toMap().containsKey('invalid'), isFalse);
    });

    test('extract handles multiple commas', () {
      final carrier = _TestCarrier();
      carrier.headers['baggage'] = 'key1=value1,,key2=value2';

      final context = propagator.extract(Context.root, carrier, getter);
      final baggage = context.baggage;

      expect(baggage.toMap()['key1']?.value, equals('value1'));
      expect(baggage.toMap()['key2']?.value, equals('value2'));
    });

    test('roundtrip preserves baggage', () {
      final originalBaggage = Baggage.empty
          .set('user', BaggageEntry('alice'))
          .set('session', BaggageEntry('xyz-123'));
      final originalContext = Context.root.withBaggage(originalBaggage);

      final carrier = _TestCarrier();
      propagator.inject(originalContext, carrier, setter);

      final extractedContext = propagator.extract(Context.root, carrier, getter);
      final extractedBaggage = extractedContext.baggage;

      expect(extractedBaggage.toMap()['user']?.value, equals('alice'));
      expect(extractedBaggage.toMap()['session']?.value, equals('xyz-123'));
    });

    test('roundtrip preserves special characters', () {
      final originalBaggage = Baggage.empty
          .set('key', BaggageEntry('value@#\$%^&*()'));
      final originalContext = Context.root.withBaggage(originalBaggage);

      final carrier = _TestCarrier();
      propagator.inject(originalContext, carrier, setter);

      final extractedContext = propagator.extract(Context.root, carrier, getter);
      final extractedBaggage = extractedContext.baggage;

      expect(extractedBaggage.toMap()['key']?.value, equals('value@#\$%^&*()'));
    });
  });
}
