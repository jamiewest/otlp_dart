import 'environment_reader_stub.dart'
    if (dart.library.io) 'environment_reader_io.dart';

class Environment {
  Environment._(this._reader);

  static final Environment instance =
      Environment._(createEnvironmentReader());

  final EnvironmentReader _reader;

  static String? getString(String key) => instance._reader[key];

  static List<String> getList(String key) {
    final raw = getString(key);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  static Duration? getDuration(String key) {
    final raw = getString(key);
    if (raw == null) {
      return null;
    }
    return _parseDuration(raw);
  }

  static int? getInt(String key) {
    final raw = getString(key);
    if (raw == null) {
      return null;
    }
    return int.tryParse(raw);
  }

  static Map<String, String> get entries => instance._reader.entries;
}

Duration? _parseDuration(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final unitMatch = RegExp(r'([0-9]+)([a-zA-Z]+)?').firstMatch(trimmed);
  if (unitMatch == null) {
    return null;
  }
  final value = int.tryParse(unitMatch.group(1)!);
  if (value == null) {
    return null;
  }
  final unit = unitMatch.group(2)?.toLowerCase();
  switch (unit) {
    case null:
    case 'ms':
      return Duration(milliseconds: value);
    case 's':
      return Duration(seconds: value);
    case 'm':
      return Duration(minutes: value);
    case 'h':
      return Duration(hours: value);
    default:
      return null;
  }
}
