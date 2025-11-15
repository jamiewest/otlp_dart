import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:test/test.dart';

void main() {
  group('BaggageEntry', () {
    test('creates entry with value', () {
      final entry = BaggageEntry('test-value');
      expect(entry.value, equals('test-value'));
      expect(entry.metadata, isNull);
    });

    test('creates entry with metadata', () {
      final metadata = BaggageEntryMetadata('meta');
      final entry = BaggageEntry('test-value', metadata);
      expect(entry.value, equals('test-value'));
      expect(entry.metadata, equals(metadata));
    });
  });

  group('Baggage', () {
    test('empty has no entries', () {
      expect(Baggage.empty.isEmpty, isTrue);
      expect(Baggage.empty.toMap(), isEmpty);
    });

    test('fromEntries creates baggage', () {
      final entries = {
        'key1': BaggageEntry('value1'),
        'key2': BaggageEntry('value2'),
      };
      final baggage = Baggage.fromEntries(entries);

      expect(baggage.isEmpty, isFalse);
      expect(baggage.toMap().length, equals(2));
    });

    test('set adds new entry', () {
      final baggage = Baggage.empty.set('key', BaggageEntry('value'));

      expect(baggage.isEmpty, isFalse);
      expect(baggage.toMap()['key']?.value, equals('value'));
    });

    test('set overwrites existing entry', () {
      final baggage = Baggage.empty
          .set('key', BaggageEntry('old'))
          .set('key', BaggageEntry('new'));

      expect(baggage.toMap()['key']?.value, equals('new'));
      expect(baggage.toMap().length, equals(1));
    });

    test('remove deletes entry', () {
      final baggage = Baggage.empty
          .set('key1', BaggageEntry('value1'))
          .set('key2', BaggageEntry('value2'))
          .remove('key1');

      expect(baggage.toMap().length, equals(1));
      expect(baggage.toMap().containsKey('key1'), isFalse);
      expect(baggage.toMap()['key2']?.value, equals('value2'));
    });

    test('remove non-existent key returns same baggage', () {
      final baggage = Baggage.empty.set('key', BaggageEntry('value'));
      final newBaggage = baggage.remove('other');

      expect(identical(baggage, newBaggage), isTrue);
    });

    test('toMap returns unmodifiable view', () {
      final baggage = Baggage.empty.set('key', BaggageEntry('value'));
      final map = baggage.toMap();

      expect(
        () => map['key'] = BaggageEntry('modified'),
        throwsUnsupportedError,
      );
    });

    test('current returns empty by default', () {
      expect(Baggage.current, equals(Baggage.empty));
    });

    test('run executes with baggage in context', () {
      final baggage = Baggage.empty.set('key', BaggageEntry('value'));

      final result = Baggage.run(baggage: baggage, body: () {
        expect(Baggage.current.toMap()['key']?.value, equals('value'));
        return 42;
      });

      expect(result, equals(42));
    });

    test('run restores previous baggage', () {
      final originalBaggage = Baggage.current;
      final testBaggage = Baggage.empty.set('key', BaggageEntry('value'));

      Baggage.run(baggage: testBaggage, body: () {
        expect(Baggage.current, isNot(equals(originalBaggage)));
      });

      expect(Baggage.current, equals(originalBaggage));
    });
  });

  group('BaggageContextExtension', () {
    test('baggage returns empty when not set', () {
      expect(Context.root.baggage, equals(Baggage.empty));
    });

    test('withBaggage sets baggage in context', () {
      final baggage = Baggage.empty.set('key', BaggageEntry('value'));
      final context = Context.root.withBaggage(baggage);

      expect(context.baggage.toMap()['key']?.value, equals('value'));
    });

    test('baggage integrates with Context.run', () {
      final baggage = Baggage.empty.set('key', BaggageEntry('value'));
      final context = Context.root.withBaggage(baggage);

      Context.run(context: context, body: () {
        expect(Context.current.baggage.toMap()['key']?.value, equals('value'));
      });
    });
  });
}
