import '../../context/baggage.dart';
import '../../context/context.dart';
import '../../trace/span.dart';
import '../../trace/span_context.dart';

/// Abstraction for injecting and extracting propagation headers.
abstract class TextMapPropagator {
  const TextMapPropagator();

  Iterable<String> get fields;

  void inject<T>(Context context, T carrier, TextMapSetter<T> setter);

  Context extract<T>(Context context, T carrier, TextMapGetter<T> getter);

  PropagatedContext extractContext<T>(T carrier, TextMapGetter<T> getter) {
    final ctx = extract(Context.current, carrier, getter);
    final spanContext = ctx.spanContext ?? SpanContext.invalid;
    final baggage = ctx.baggage;
    return PropagatedContext(spanContext, baggage);
  }
}

/// Sets propagation values into a carrier.
abstract class TextMapSetter<T> {
  void set(T carrier, String key, String value);
}

/// Reads propagation values from a carrier.
abstract class TextMapGetter<T> {
  Iterable<String> keys(T carrier);

  String? get(T carrier, String key);
}

/// Combines the SpanContext and Baggage flowing across request boundaries.
class PropagatedContext {
  const PropagatedContext(this.spanContext, this.baggage);

  final SpanContext spanContext;
  final Baggage baggage;
}
