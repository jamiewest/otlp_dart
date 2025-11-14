import 'dart:collection';

/// Valid attribute value types per the OpenTelemetry specification.
typedef AttributeValue = Object?;

bool _isPrimitiveValue(Object? value) =>
    value is String || value is bool || value is int || value is double;

AttributeValue _normalizeValue(Object? value) {
  if (value == null) {
    return null;
  }
  if (_isPrimitiveValue(value)) {
    return value;
  }
  if (value is Iterable) {
    final normalized = value.map(_normalizeValue).toList(growable: false);
    if (normalized.any((element) => element == null)) {
      throw ArgumentError('Attribute lists may not contain null entries.');
    }
    return List<AttributeValue>.unmodifiable(normalized);
  }

  throw ArgumentError(
    'Unsupported attribute value. Only String, bool, int, double, or lists of '
    'those types are allowed. Received: ${value.runtimeType}',
  );
}

/// Mutable attribute map used by Spans and Resources.
class Attributes {
  Attributes([Map<String, AttributeValue> entries = const {}])
      : _values = <String, AttributeValue>{} {
    entries.forEach(set);
  }

  final Map<String, AttributeValue> _values;

  bool get isEmpty => _values.isEmpty;

  AttributeValue? operator [](String key) => _values[key];

  void operator []=(String key, AttributeValue? value) => set(key, value);

  void set(String key, AttributeValue? value) {
    if (value == null) {
      _values.remove(key);
      return;
    }
    _values[key] = _normalizeValue(value);
  }

  void addAll(Map<String, AttributeValue> entries) {
    entries.forEach(set);
  }

  Map<String, AttributeValue> toMap() => UnmodifiableMapView(_values);

  Attributes copy() => Attributes(_values);
}
