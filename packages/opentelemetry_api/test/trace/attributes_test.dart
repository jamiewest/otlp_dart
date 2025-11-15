import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:test/test.dart';

void main() {
  group('Attributes', () {
    test('empty attributes', () {
      final attrs = Attributes();
      expect(attrs.isEmpty, isTrue);
      expect(attrs.toMap(), isEmpty);
    });

    test('constructor accepts initial values', () {
      final attrs = Attributes({'key': 'value', 'count': 42});
      expect(attrs['key'], equals('value'));
      expect(attrs['count'], equals(42));
      expect(attrs.isEmpty, isFalse);
    });

    test('set adds string values', () {
      final attrs = Attributes();
      attrs.set('name', 'test');
      expect(attrs['name'], equals('test'));
    });

    test('set adds numeric values', () {
      final attrs = Attributes();
      attrs.set('count', 123);
      attrs.set('ratio', 3.14);
      expect(attrs['count'], equals(123));
      expect(attrs['ratio'], equals(3.14));
    });

    test('set adds boolean values', () {
      final attrs = Attributes();
      attrs.set('enabled', true);
      expect(attrs['enabled'], isTrue);
    });

    test('set adds list values', () {
      final attrs = Attributes();
      attrs.set('tags', ['a', 'b', 'c']);
      final list = attrs['tags'] as List;
      expect(list, equals(['a', 'b', 'c']));
    });

    test('set normalizes list values', () {
      final attrs = Attributes();
      attrs.set('numbers', [1, 2, 3]);
      final list = attrs['numbers'] as List;
      expect(list, equals([1, 2, 3]));
    });

    test('set throws on null in list', () {
      final attrs = Attributes();
      expect(
        () => attrs.set('bad', ['a', null, 'c']),
        throwsArgumentError,
      );
    });

    test('set throws on unsupported types', () {
      final attrs = Attributes();
      expect(() => attrs.set('bad', DateTime.now()), throwsArgumentError);
      expect(() => attrs.set('bad', {'nested': 'map'}), throwsArgumentError);
    });

    test('set with null removes key', () {
      final attrs = Attributes({'key': 'value'});
      attrs.set('key', null);
      expect(attrs['key'], isNull);
      expect(attrs.isEmpty, isTrue);
    });

    test('bracket operator sets values', () {
      final attrs = Attributes();
      attrs['key'] = 'value';
      expect(attrs['key'], equals('value'));
    });

    test('addAll merges multiple entries', () {
      final attrs = Attributes({'a': 1});
      attrs.addAll({'b': 2, 'c': 3});
      expect(attrs['a'], equals(1));
      expect(attrs['b'], equals(2));
      expect(attrs['c'], equals(3));
    });

    test('addAll overwrites existing keys', () {
      final attrs = Attributes({'key': 'old'});
      attrs.addAll({'key': 'new'});
      expect(attrs['key'], equals('new'));
    });

    test('toMap returns unmodifiable view', () {
      final attrs = Attributes({'key': 'value'});
      final map = attrs.toMap();

      expect(() => map['key'] = 'modified', throwsUnsupportedError);
    });

    test('toMap reflects current state', () {
      final attrs = Attributes({'a': 1});
      final map1 = attrs.toMap();
      expect(map1['a'], equals(1));

      attrs.set('b', 2);
      final map2 = attrs.toMap();
      expect(map2['b'], equals(2));

      // map1 is a view and reflects changes
      expect(map1.containsKey('b'), isTrue);
    });

    test('copy creates independent copy', () {
      final attrs = Attributes({'key': 'value'});
      final copy = attrs.copy();

      copy.set('key', 'modified');
      copy.set('new', 'data');

      expect(attrs['key'], equals('value'));
      expect(attrs['new'], isNull);
      expect(copy['key'], equals('modified'));
      expect(copy['new'], equals('data'));
    });

    test('supports all primitive types', () {
      final attrs = Attributes({
        'string': 'text',
        'int': 42,
        'double': 3.14,
        'bool': true,
        'stringList': ['a', 'b'],
        'intList': [1, 2, 3],
        'doubleList': [1.1, 2.2],
        'boolList': [true, false],
      });

      expect(attrs['string'], equals('text'));
      expect(attrs['int'], equals(42));
      expect(attrs['double'], equals(3.14));
      expect(attrs['bool'], isTrue);
      expect(attrs['stringList'], equals(['a', 'b']));
      expect(attrs['intList'], equals([1, 2, 3]));
      expect(attrs['doubleList'], equals([1.1, 2.2]));
      expect(attrs['boolList'], equals([true, false]));
    });

    test('list values are immutable', () {
      final attrs = Attributes();
      attrs.set('list', ['a', 'b']);
      final list = attrs['list'] as List;

      expect(() => list.add('c'), throwsUnsupportedError);
    });
  });
}
