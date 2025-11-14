import 'dart:async';

import 'package:collection/collection.dart';

/// Represents a bag of key/value pairs that flows with execution.
class Context {
  Context._(Map<Object, Object?> values)
      : _values = Map<Object, Object?>.unmodifiable(values);

  /// Root context that contains no values.
  static final Context root = Context._(const {});

  final Map<Object, Object?> _values;

  static final Object _zoneKey = Object();

  /// Returns the Context that is currently attached to the async Zone.
  static Context get current =>
      (Zone.current[_zoneKey] as Context?) ?? Context.root;

  /// Runs [body] with the provided [context] attached to the async Zone.
  static R run<R>({Context? context, required R Function() body}) {
    final ctx = context ?? Context.current;
    if (identical(ctx, Context.current)) {
      return body();
    }

    return runZoned(body, zoneValues: {_zoneKey: ctx});
  }

  /// Returns a new Context that includes the provided [key]/[value].
  Context withValue<T>(ContextKey<T> key, T value) {
    final updated = Map<Object, Object?>.from(_values);
    updated[key] = value;
    return Context._(updated);
  }

  /// Looks up a value inside the Context for the provided [key].
  T? getValue<T>(ContextKey<T> key) => _values[key] as T?;

  /// Returns a copy without the provided [key].
  Context withoutValue(ContextKey key) {
    if (!_values.containsKey(key)) {
      return this;
    }
    final updated = Map<Object, Object?>.from(_values);
    updated.remove(key);
    return Context._(updated);
  }

  /// Converts the context into a read-only map.
  Map<Object, Object?> asMap() => UnmodifiableMapView(_values);

  @override
  bool operator ==(Object other) =>
      other is Context && const MapEquality().equals(other._values, _values);

  @override
  int get hashCode => const MapEquality().hash(_values);
}

/// Key used to place typed values in a [Context].
class ContextKey<T> {
  const ContextKey(this.name);

  final String name;

  @override
  String toString() => 'ContextKey<$T>(name: $name)';
}
