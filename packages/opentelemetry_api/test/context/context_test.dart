import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:test/test.dart';

void main() {
  group('Context', () {
    test('root context is empty', () {
      expect(Context.root.asMap(), isEmpty);
    });

    test('current returns root by default', () {
      expect(Context.current, equals(Context.root));
    });

    test('withValue adds key-value pair', () {
      final key = ContextKey<String>('test');
      final ctx = Context.root.withValue(key, 'value');

      expect(ctx.getValue(key), equals('value'));
    });

    test('withValue supports different types', () {
      final stringKey = ContextKey<String>('string');
      final intKey = ContextKey<int>('int');
      final boolKey = ContextKey<bool>('bool');

      final ctx = Context.root
          .withValue(stringKey, 'test')
          .withValue(intKey, 42)
          .withValue(boolKey, true);

      expect(ctx.getValue(stringKey), equals('test'));
      expect(ctx.getValue(intKey), equals(42));
      expect(ctx.getValue(boolKey), isTrue);
    });

    test('getValue returns null for missing key', () {
      final key = ContextKey<String>('missing');
      expect(Context.root.getValue(key), isNull);
    });

    test('withValue overwrites existing key', () {
      final key = ContextKey<String>('test');
      final ctx = Context.root
          .withValue(key, 'first')
          .withValue(key, 'second');

      expect(ctx.getValue(key), equals('second'));
    });

    test('withoutValue removes key', () {
      final key = ContextKey<String>('test');
      final ctx = Context.root
          .withValue(key, 'value')
          .withoutValue(key);

      expect(ctx.getValue(key), isNull);
    });

    test('withoutValue on missing key returns same context', () {
      final key = ContextKey<String>('missing');
      final ctx = Context.root.withoutValue(key);

      expect(identical(ctx, Context.root), isTrue);
    });

    test('run executes function with context', () {
      final key = ContextKey<String>('test');
      final ctx = Context.root.withValue(key, 'value');

      final result = Context.run(context: ctx, body: () {
        expect(Context.current, equals(ctx));
        expect(Context.current.getValue(key), equals('value'));
        return 42;
      });

      expect(result, equals(42));
    });

    test('run restores previous context after execution', () {
      final key = ContextKey<String>('test');
      final ctx = Context.root.withValue(key, 'value');
      final originalContext = Context.current;

      Context.run(context: ctx, body: () {
        expect(Context.current.getValue(key), equals('value'));
      });

      expect(Context.current, equals(originalContext));
    });

    test('run supports nested contexts', () {
      final key1 = ContextKey<String>('key1');
      final key2 = ContextKey<String>('key2');

      final ctx1 = Context.root.withValue(key1, 'value1');
      final ctx2 = Context.root.withValue(key2, 'value2');

      Context.run(context: ctx1, body: () {
        expect(Context.current.getValue(key1), equals('value1'));
        expect(Context.current.getValue(key2), isNull);

        Context.run(context: ctx2, body: () {
          expect(Context.current.getValue(key1), isNull);
          expect(Context.current.getValue(key2), equals('value2'));
        });

        expect(Context.current.getValue(key1), equals('value1'));
      });
    });

    test('run with null context uses current', () {
      final key = ContextKey<String>('test');
      final ctx = Context.root.withValue(key, 'value');

      Context.run(context: ctx, body: () {
        Context.run(context: null, body: () {
          expect(Context.current.getValue(key), equals('value'));
        });
      });
    });

    test('asMap returns unmodifiable map', () {
      final key = ContextKey<String>('test');
      final ctx = Context.root.withValue(key, 'value');
      final map = ctx.asMap();

      expect(map[key], equals('value'));
      expect(() => map[key] = 'modified', throwsUnsupportedError);
    });

    test('equality works correctly', () {
      final key1 = ContextKey<String>('key1');
      final key2 = ContextKey<String>('key2');

      final ctx1a = Context.root.withValue(key1, 'value');
      final ctx1b = Context.root.withValue(key1, 'value');
      final ctx2 = Context.root.withValue(key2, 'value');

      expect(ctx1a, equals(ctx1b));
      expect(ctx1a, isNot(equals(ctx2)));
      expect(Context.root, equals(Context.root));
    });

    test('hashCode is consistent', () {
      final key = ContextKey<String>('test');
      final ctx1 = Context.root.withValue(key, 'value');
      final ctx2 = Context.root.withValue(key, 'value');

      expect(ctx1.hashCode, equals(ctx2.hashCode));
    });
  });

  group('ContextKey', () {
    test('has name and type', () {
      final key = ContextKey<String>('test');
      expect(key.name, equals('test'));
    });

    test('toString includes type and name', () {
      final key = ContextKey<int>('counter');
      expect(key.toString(), contains('int'));
      expect(key.toString(), contains('counter'));
    });

    test('different instances are different keys', () {
      final key1 = ContextKey<String>('test');
      final key2 = ContextKey<String>('test');

      final ctx = Context.root.withValue(key1, 'value');
      expect(ctx.getValue(key2), isNull);
    });
  });
}
