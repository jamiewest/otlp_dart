import '../../context/baggage.dart';
import '../../context/context.dart';
import '../../trace/span.dart';
import '../../trace/span_context.dart';
import 'baggage_propagator.dart';
import 'composite_text_map_propagator.dart';
import 'text_map_propagator.dart';
import 'trace_context_propagator.dart';

class Propagators {
  Propagators._();

  static TextMapPropagator _textMapPropagator =
      CompositeTextMapPropagator([
    TraceContextPropagator.instance,
    BaggagePropagator.instance,
  ]);

  static TextMapPropagator get textMapPropagator => _textMapPropagator;

  static set textMapPropagator(TextMapPropagator propagator) {
    _textMapPropagator = propagator;
  }

  static Context buildContext({
    SpanContext? spanContext,
    Baggage? baggage,
  }) {
    var context = Context.current;
    if (spanContext != null && spanContext.isValid) {
      context = context.withSpanContext(spanContext);
    }
    if (baggage != null) {
      context = context.withBaggage(baggage);
    }
    return context;
  }
}
