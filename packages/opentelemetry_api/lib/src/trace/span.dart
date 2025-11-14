import '../context/context.dart';
import 'attributes.dart';
import 'span_context.dart';
import 'span_kind.dart';
import 'status.dart';

/// Represents an event attached to a span timeline.
class SpanEvent {
  SpanEvent(this.name, {Map<String, AttributeValue> attributes = const {}, DateTime? timestamp})
      : attributes = Attributes(attributes),
        timestamp = timestamp ?? DateTime.now().toUtc();

  final String name;
  final Attributes attributes;
  final DateTime timestamp;
}

/// Span contract exposed by the API.
abstract class Span {
  SpanContext get context;
  SpanContext? get parentSpanContext;
  String get name;
  SpanKind get kind;
  bool get isRecording;
  DateTime get startTime;

  void setAttribute(String key, AttributeValue? value);
  void addEvent(String name,
      {Map<String, AttributeValue> attributes = const {},
      DateTime? timestamp});
  void recordException(Object error, {StackTrace? stackTrace, Map<String, AttributeValue>? attributes});
  void setStatus(Status status);
  void updateName(String name);
  void end({DateTime? endTime});
}

/// Context key used to flow the currently active span.
final ContextKey<Span> currentSpanKey =
    ContextKey<Span>('opentelemetry.activeSpan');
final ContextKey<SpanContext> spanContextKey =
    ContextKey<SpanContext>('opentelemetry.spanContext');

extension ActiveSpanContext on Context {
  Span? get activeSpan => getValue(currentSpanKey);

  SpanContext? get spanContext =>
      activeSpan?.context ?? getValue(spanContextKey);

  Context withSpan(Span span) =>
      withValue(currentSpanKey, span).withSpanContext(span.context);

  Context withSpanContext(SpanContext spanContext) =>
      withValue(spanContextKey, spanContext);
}

class NoopSpan implements Span {
  NoopSpan()
      : context = SpanContext.invalid,
        parentSpanContext = SpanContext.invalid;

  @override
  final SpanContext context;

  @override
  final SpanContext? parentSpanContext;

  @override
  bool get isRecording => false;

  @override
  SpanKind get kind => SpanKind.internal;

  @override
  String get name => 'noop';

  @override
  DateTime get startTime => DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  @override
  void addEvent(String name,
      {Map<String, AttributeValue> attributes = const {},
      DateTime? timestamp}) {}

  @override
  void end({DateTime? endTime}) {}

  @override
  void recordException(Object error, {StackTrace? stackTrace, Map<String, AttributeValue>? attributes}) {}

  @override
  void setAttribute(String key, AttributeValue? value) {}

  @override
  void setStatus(Status status) {}

  @override
  void updateName(String name) {}
}
