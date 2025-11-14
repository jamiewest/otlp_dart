import '../../context/baggage.dart';
import '../../trace/span_context.dart';

class PropagationContext {
  const PropagationContext(this.spanContext, this.baggage);

  final SpanContext spanContext;
  final Baggage baggage;
}
