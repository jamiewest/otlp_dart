import 'dart:collection';

import 'context.dart';

/// Metadata that travels alongside a baggage entry.
class BaggageEntryMetadata {
  const BaggageEntryMetadata([this.value]);

  final String? value;
}

/// Represents a single baggage item.
class BaggageEntry {
  const BaggageEntry(this.value, [this.metadata]);

  final String value;
  final BaggageEntryMetadata? metadata;
}

/// Propagated bag of string key/value pairs.
class Baggage {
  const Baggage._(this._entries);

  static const Baggage empty = Baggage._({});

  factory Baggage.fromEntries(Map<String, BaggageEntry> entries) =>
      Baggage._(Map<String, BaggageEntry>.unmodifiable(entries));

  static final ContextKey<Baggage> _baggageKey =
      ContextKey<Baggage>('opentelemetry.baggage');

  final Map<String, BaggageEntry> _entries;

  Map<String, BaggageEntry> toMap() => UnmodifiableMapView(_entries);

  bool get isEmpty => _entries.isEmpty;

  Baggage set(String key, BaggageEntry entry) {
    final updated = Map<String, BaggageEntry>.from(_entries);
    updated[key] = entry;
    return Baggage._(updated);
  }

  Baggage remove(String key) {
    if (!_entries.containsKey(key)) {
      return this;
    }
    final updated = Map<String, BaggageEntry>.from(_entries);
    updated.remove(key);
    return Baggage._(updated);
  }

  static Baggage get current =>
      Context.current.getValue(_baggageKey) ?? Baggage.empty;

  static R run<R>({required Baggage baggage, required R Function() body}) {
    final context = Context.current.withValue(_baggageKey, baggage);
    return Context.run(context: context, body: body);
  }
}

extension BaggageContextExtension on Context {
  Baggage get baggage => getValue(Baggage._baggageKey) ?? Baggage.empty;

  Context withBaggage(Baggage baggage) => withValue(Baggage._baggageKey, baggage);
}
