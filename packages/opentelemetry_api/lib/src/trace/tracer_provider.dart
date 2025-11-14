import '../context/context.dart';
import 'attributes.dart';
import 'link.dart';
import 'span.dart';
import 'span_kind.dart';
import 'tracer.dart';

abstract class TracerProvider {
  Tracer getTracer(String name, {String? version, String? schemaUrl});

  Future<void> forceFlush() async {}

  Future<void> shutdown() async {}
}

class NoopTracerProvider implements TracerProvider {
  const NoopTracerProvider();

  static const NoopTracerProvider instance = NoopTracerProvider();

  @override
  Tracer getTracer(String name, {String? version, String? schemaUrl}) =>
      _NoopTracer();

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {}
}

class _NoopTracer extends Tracer {
  @override
  Span startSpan(String name,
          {Context? context,
          SpanKind kind = SpanKind.internal,
          Map<String, AttributeValue> attributes = const {},
          List<Link> links = const [],
          DateTime? startTime}) =>
      NoopSpan();
}
