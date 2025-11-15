import 'package:opentelemetry/opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('Resource', () {
    test('constructor creates resource with attributes', () {
      final resource = Resource({'service.name': 'test-service', 'version': '1.0'});

      expect(resource.attributes['service.name'], equals('test-service'));
      expect(resource.attributes['version'], equals('1.0'));
    });

    test('constructor with no attributes creates empty resource', () {
      final resource = Resource();

      expect(resource.attributes.isEmpty, isTrue);
    });

    test('defaultResource includes service name', () {
      final resource = Resource.defaultResource();

      expect(resource.attributes['service.name'], isNotNull);
      expect(resource.attributes['service.name'], contains('dart'));
    });

    test('merge combines attributes from both resources', () {
      final resource1 = Resource({'key1': 'value1', 'common': 'first'});
      final resource2 = Resource({'key2': 'value2', 'common': 'second'});

      final merged = resource1.merge(resource2);

      expect(merged.attributes['key1'], equals('value1'));
      expect(merged.attributes['key2'], equals('value2'));
      expect(merged.attributes['common'], equals('second')); // Second overwrites first
    });

    test('merge preserves original resources', () {
      final resource1 = Resource({'key1': 'value1'});
      final resource2 = Resource({'key2': 'value2'});

      resource1.merge(resource2);

      expect(resource1.attributes['key2'], isNull);
      expect(resource2.attributes['key1'], isNull);
    });

    test('merge with empty resource', () {
      final resource1 = Resource({'key1': 'value1'});
      final resource2 = Resource();

      final merged = resource1.merge(resource2);

      expect(merged.attributes['key1'], equals('value1'));
    });

    test('toMap returns attributes map', () {
      final resource = Resource({'key1': 'value1', 'key2': 'value2'});

      final map = resource.toMap();

      expect(map['key1'], equals('value1'));
      expect(map['key2'], equals('value2'));
    });

    test('toMap is unmodifiable view', () {
      final resource = Resource({'key': 'value'});
      final map = resource.toMap();

      expect(() => map['key'] = 'modified', throwsUnsupportedError);
    });

    test('supports all attribute types', () {
      final resource = Resource({
        'string': 'text',
        'int': 42,
        'double': 3.14,
        'bool': true,
        'list': ['a', 'b', 'c'],
      });

      expect(resource.attributes['string'], equals('text'));
      expect(resource.attributes['int'], equals(42));
      expect(resource.attributes['double'], equals(3.14));
      expect(resource.attributes['bool'], isTrue);
      expect(resource.attributes['list'], equals(['a', 'b', 'c']));
    });

    test('merge handles complex attribute types', () {
      final resource1 = Resource({'numbers': [1, 2, 3]});
      final resource2 = Resource({'numbers': [4, 5, 6]});

      final merged = resource1.merge(resource2);

      expect(merged.attributes['numbers'], equals([4, 5, 6]));
    });

    test('chained merge operations', () {
      final r1 = Resource({'a': '1'});
      final r2 = Resource({'b': '2'});
      final r3 = Resource({'c': '3'});

      final merged = r1.merge(r2).merge(r3);

      expect(merged.attributes['a'], equals('1'));
      expect(merged.attributes['b'], equals('2'));
      expect(merged.attributes['c'], equals('3'));
    });
  });
}
