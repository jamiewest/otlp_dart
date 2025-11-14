import 'dart:math';

final Random _random = _createRandom();

Random _createRandom() {
  try {
    return Random.secure();
  } catch (_) {
    return Random();
  }
}

String _generateHex(int bytes) {
  final buffer = StringBuffer();
  for (var i = 0; i < bytes; i++) {
    final part = _random.nextInt(256);
    buffer.write(part.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

class TraceId {
  TraceId._(this.value);

  static final TraceId invalid = TraceId._('0' * 32);

  final String value;

  bool get isValid => value != invalid.value;

  @override
  String toString() => value;

  static TraceId random() => TraceId._(_generateHex(16));

  factory TraceId.fromHex(String hex) {
    if (hex.length != 32) {
      throw ArgumentError('TraceId must be 16 bytes / 32 hex characters.');
    }
    return TraceId._(hex.toLowerCase());
  }
}

class SpanId {
  SpanId._(this.value);

  static final SpanId invalid = SpanId._('0' * 16);

  final String value;

  bool get isValid => value != invalid.value;

  @override
  String toString() => value;

  static SpanId random() => SpanId._(_generateHex(8));

  factory SpanId.fromHex(String hex) {
    if (hex.length != 16) {
      throw ArgumentError('SpanId must be 8 bytes / 16 hex characters.');
    }
    return SpanId._(hex.toLowerCase());
  }
}

class TraceFlags {
  const TraceFlags._(this.value);

  final int value;

  static const TraceFlags none = TraceFlags._(0);
  static const TraceFlags sampled = TraceFlags._(0x1);

  factory TraceFlags.fromByte(int value) => TraceFlags._(value & 0xff);

  bool get isSampled => (value & 0x1) == 0x1;
}

class TraceState {
  TraceState([List<MapEntry<String, String>> entries = const []])
      : entries = List<MapEntry<String, String>>.unmodifiable(entries);

  const TraceState._internal(this.entries);

  static const TraceState empty =
      TraceState._internal(<MapEntry<String, String>>[]);

  final List<MapEntry<String, String>> entries;

  TraceState put(String key, String value) {
    final filtered = entries.where((e) => e.key != key).toList(growable: true);
    filtered.insert(0, MapEntry(key, value));
    return TraceState(filtered);
  }

  TraceState remove(String key) {
    final filtered = entries.where((element) => element.key != key).toList();
    return TraceState(filtered);
  }

  bool get isEmpty => entries.isEmpty;
}

class SpanContext {
  const SpanContext({
    required this.traceId,
    required this.spanId,
    this.traceFlags = TraceFlags.none,
    this.traceState = TraceState.empty,
    this.isRemote = false,
  });

  final TraceId traceId;
  final SpanId spanId;
  final TraceFlags traceFlags;
  final TraceState traceState;
  final bool isRemote;

  bool get isSampled => traceFlags.isSampled;

  bool get isValid => traceId.isValid && spanId.isValid;

  static final SpanContext invalid = SpanContext(
    traceId: TraceId.invalid,
    spanId: SpanId.invalid,
  );
}
