import '../context/context.dart';
import 'attributes.dart';
import 'link.dart';
import 'span.dart';
import 'span_kind.dart';

abstract class Tracer {
  Span startSpan(
    String name, {
    Context? context,
    SpanKind kind = SpanKind.internal,
    Map<String, AttributeValue> attributes = const {},
    List<Link> links = const [],
    DateTime? startTime,
  });

  R withSpan<R>(Span span, R Function() body) {
    final ctx = Context.current.withSpan(span);
    return Context.run(context: ctx, body: body);
  }
}
