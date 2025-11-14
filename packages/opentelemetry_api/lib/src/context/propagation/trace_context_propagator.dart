import '../../context/context.dart';
import '../../trace/span.dart';
import '../../trace/span_context.dart';
import 'text_map_propagator.dart';

class TraceContextPropagator extends TextMapPropagator {
  const TraceContextPropagator._();

  static const TraceContextPropagator instance = TraceContextPropagator._();

  static const _traceParentHeader = 'traceparent';
  static const _traceStateHeader = 'tracestate';

  @override
  Iterable<String> get fields => const [_traceParentHeader, _traceStateHeader];

  @override
  Context extract<T>(Context context, T carrier, TextMapGetter<T> getter) {
    final header = getter.get(carrier, _traceParentHeader);
    if (header == null) {
      return context;
    }
    final parsed = _parseTraceParent(header);
    if (parsed == null) {
      return context;
    }
    final traceStateHeader = getter.get(carrier, _traceStateHeader);
    final traceState = _parseTraceState(traceStateHeader);
    final spanContext = SpanContext(
      traceId: parsed.traceId,
      spanId: parsed.spanId,
      traceFlags: parsed.traceFlags,
      traceState: traceState,
      isRemote: true,
    );
    return context.withSpanContext(spanContext);
  }

  @override
  void inject<T>(Context context, T carrier, TextMapSetter<T> setter) {
    final spanContext = context.spanContext;
    if (spanContext == null || !spanContext.isValid) {
      return;
    }
    final traceFlags = spanContext.traceFlags.value.toRadixString(16).padLeft(2, '0');
    final traceParent =
        '00-${spanContext.traceId.value}-${spanContext.spanId.value}-$traceFlags';
    setter.set(carrier, _traceParentHeader, traceParent);
    if (!spanContext.traceState.isEmpty) {
      final traceStateValue = spanContext.traceState.entries
          .map((e) => '${e.key}=${e.value}')
          .join(',');
      setter.set(carrier, _traceStateHeader, traceStateValue);
    }
  }
}

_TraceParent? _parseTraceParent(String header) {
  final parts = header.trim().split('-');
  if (parts.length < 4) {
    return null;
  }
  try {
    final traceId = TraceId.fromHex(parts[1]);
    final spanId = SpanId.fromHex(parts[2]);
    final traceFlags = int.parse(parts[3], radix: 16);
    return _TraceParent(
      traceId,
      spanId,
      TraceFlags.fromByte(traceFlags),
    );
  } catch (_) {
    return null;
  }
}

TraceState _parseTraceState(String? header) {
  if (header == null || header.isEmpty) {
    return TraceState.empty;
  }
  final entries = header.split(',');
  final result = <MapEntry<String, String>>[];
  for (final entry in entries) {
    final trimmed = entry.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    final eqIndex = trimmed.indexOf('=');
    if (eqIndex <= 0) {
      continue;
    }
    final key = trimmed.substring(0, eqIndex);
    final value = trimmed.substring(eqIndex + 1);
    if (key.isEmpty || value.isEmpty) {
      continue;
    }
    result.add(MapEntry(key, value));
  }
  if (result.isEmpty) {
    return TraceState.empty;
  }
  return TraceState(result);
}

class _TraceParent {
  _TraceParent(this.traceId, this.spanId, this.traceFlags);

  final TraceId traceId;
  final SpanId spanId;
  final TraceFlags traceFlags;
}
