import 'dart:convert';
import 'dart:typed_data';

import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:opentelemetry_shared/opentelemetry_shared.dart';

List<Map<String, Object?>> encodeAttributes(
    Map<String, AttributeValue> attributes) {
  return attributes.entries
      .map((entry) => {
            'key': entry.key,
            'value': encodeAttributeValue(entry.value),
          })
      .toList();
}

Map<String, Object?> encodeAttributeValue(Object? value) {
  if (value is String) {
    return {'stringValue': value};
  }
  if (value is bool) {
    return {'boolValue': value};
  }
  if (value is int) {
    return {'intValue': value.toString()};
  }
  if (value is double) {
    return {'doubleValue': value};
  }
  if (value is Iterable) {
    return {
      'arrayValue': {
        'values': value.map(encodeAttributeValue).toList(),
      }
    };
  }
  throw ArgumentError('Unsupported attribute value type: ${value.runtimeType}');
}

Map<String, Object?> encodeInstrumentationScope(
        InstrumentationScope scope) =>
    {
      'name': scope.name,
      if (scope.version != null) 'version': scope.version,
      if (scope.schemaUrl != null) 'schemaUrl': scope.schemaUrl,
    };

int toUnixNanos(DateTime timestamp) =>
    timestamp.toUtc().microsecondsSinceEpoch * 1000;

String hexToBase64(String hex) => base64Encode(hexToBytes(hex));

Uint8List hexToBytes(String hex) {
  final length = hex.length;
  final bytes = Uint8List(length ~/ 2);
  for (var i = 0; i < length; i += 2) {
    final byte = int.parse(hex.substring(i, i + 2), radix: 16);
    bytes[i ~/ 2] = byte;
  }
  return bytes;
}
