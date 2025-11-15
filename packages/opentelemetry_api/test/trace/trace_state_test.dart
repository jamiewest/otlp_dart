import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:test/test.dart';

void main() {
  group('TraceState', () {
    test('empty has no entries', () {
      expect(TraceState.empty.entries, isEmpty);
      expect(TraceState.empty.isEmpty, isTrue);
    });

    test('constructor creates immutable list', () {
      final entries = [MapEntry('key1', 'value1'), MapEntry('key2', 'value2')];
      final state = TraceState(entries);

      expect(state.entries.length, equals(2));
      expect(state.isEmpty, isFalse);

      // Original list modification shouldn't affect TraceState
      entries.clear();
      expect(state.entries.length, equals(2));
    });

    test('put adds new entry at beginning', () {
      final state = TraceState.empty.put('key1', 'value1');

      expect(state.entries.length, equals(1));
      expect(state.entries.first.key, equals('key1'));
      expect(state.entries.first.value, equals('value1'));
    });

    test('put replaces existing key and moves to front', () {
      final state = TraceState.empty
          .put('key1', 'value1')
          .put('key2', 'value2')
          .put('key3', 'value3')
          .put('key1', 'updated');

      expect(state.entries.length, equals(3));
      expect(state.entries.first.key, equals('key1'));
      expect(state.entries.first.value, equals('updated'));
      expect(state.entries[1].key, equals('key3'));
      expect(state.entries[2].key, equals('key2'));
    });

    test('remove deletes entry', () {
      final state = TraceState.empty
          .put('key1', 'value1')
          .put('key2', 'value2')
          .remove('key1');

      expect(state.entries.length, equals(1));
      expect(state.entries.first.key, equals('key2'));
    });

    test('remove non-existent key returns new state', () {
      final state = TraceState.empty.put('key1', 'value1');
      final newState = state.remove('key2');

      expect(newState.entries.length, equals(1));
      expect(newState.entries.first.key, equals('key1'));
    });

    test('remove all entries results in empty state', () {
      final state = TraceState.empty
          .put('key1', 'value1')
          .remove('key1');

      expect(state.isEmpty, isTrue);
    });

    test('chaining operations preserves order', () {
      final state = TraceState.empty
          .put('a', '1')
          .put('b', '2')
          .put('c', '3');

      expect(state.entries[0].key, equals('c'));
      expect(state.entries[1].key, equals('b'));
      expect(state.entries[2].key, equals('a'));
    });
  });
}
