import '../../context/baggage.dart';
import '../../context/context.dart';
import 'text_map_propagator.dart';

class BaggagePropagator extends TextMapPropagator {
  const BaggagePropagator._();

  static const BaggagePropagator instance = BaggagePropagator._();

  static const _headerName = 'baggage';

  @override
  Iterable<String> get fields => const [_headerName];

  @override
  Context extract<T>(Context context, T carrier, TextMapGetter<T> getter) {
    final header = getter.get(carrier, _headerName);
    if (header == null || header.isEmpty) {
      return context;
    }
    final entries = <String, BaggageEntry>{};
    for (final part in header.split(',')) {
      final section = part.trim();
      if (section.isEmpty) {
        continue;
      }
      final eqIndex = section.indexOf('=');
      if (eqIndex <= 0) {
        continue;
      }
      final key = section.substring(0, eqIndex).trim();
      final value = section.substring(eqIndex + 1).trim();
      if (key.isEmpty || value.isEmpty) {
        continue;
      }
      entries[key] = BaggageEntry(Uri.decodeComponent(value));
    }
    if (entries.isEmpty) {
      return context;
    }
    return context.withBaggage(Baggage.fromEntries(entries));
  }

  @override
  void inject<T>(Context context, T carrier, TextMapSetter<T> setter) {
    final baggage = context.baggage;
    if (baggage.isEmpty) {
      return;
    }
    final encoded = baggage
        .toMap()
        .entries
        .map((entry) =>
            '${entry.key}=${Uri.encodeComponent(entry.value.value)}')
        .join(',');
    setter.set(carrier, _headerName, encoded);
  }
}
