import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:opentelemetry_shared/opentelemetry_shared.dart';

import '../resource/resource.dart';
import 'span_data.dart';

typedef SpanEndCallback = void Function(SdkSpan span);

abstract class ReadableSpan implements Span {
  Resource get resource;
  InstrumentationScope get instrumentationScope;

  SpanData toSpanData();
}

class SdkSpan implements ReadableSpan {
  SdkSpan({
    required SpanContext context,
    required this.parentSpanContext,
    required String name,
    required this.kind,
    required Attributes attributes,
    required List<Link> links,
    required DateTime startTime,
    required this.resource,
    required this.instrumentationScope,
    required SpanEndCallback onEnded,
  })  : _context = context,
        _name = name,
        _attributes = Attributes(attributes.toMap()),
        _links = List<Link>.from(links),
        _startTime = startTime,
        _endCallback = onEnded;

  final SpanContext _context;
  final List<Link> _links;
  final List<SpanEvent> _events = <SpanEvent>[];
  final Attributes _attributes;
  final DateTime _startTime;
  final SpanEndCallback _endCallback;

  bool _hasEnded = false;
  bool _isRecording = true;
  DateTime? _endTime;
  Status _status = Status.unset;
  String _name;

  @override
  final SpanContext? parentSpanContext;

  @override
  final SpanKind kind;

  @override
  final Resource resource;

  @override
  final InstrumentationScope instrumentationScope;

  @override
  SpanContext get context => _context;

  @override
  String get name => _name;

  @override
  bool get isRecording => !_hasEnded && _isRecording;

  @override
  DateTime get startTime => _startTime;

  @override
  void addEvent(String name,
      {Map<String, AttributeValue> attributes = const {},
      DateTime? timestamp}) {
    if (!isRecording) {
      return;
    }
    _events.add(SpanEvent(name, attributes: attributes, timestamp: timestamp));
  }

  @override
  void end({DateTime? endTime}) {
    if (_hasEnded) {
      return;
    }
    _hasEnded = true;
    _isRecording = false;
    _endTime = (endTime ?? DateTime.now().toUtc());
    _endCallback(this);
  }

  @override
  void recordException(Object error,
      {StackTrace? stackTrace, Map<String, AttributeValue>? attributes}) {
    if (!isRecording) {
      return;
    }
    addEvent('exception', attributes: {
      'exception.type': error.runtimeType.toString(),
      'exception.message': error.toString(),
      if (stackTrace != null) 'exception.stacktrace': stackTrace.toString(),
      ...?attributes,
    });
  }

  @override
  void setAttribute(String key, AttributeValue? value) {
    if (!isRecording) {
      return;
    }
    _attributes.set(key, value);
  }

  @override
  void setStatus(Status status) {
    if (!isRecording) {
      return;
    }
    _status = status;
  }

  @override
  void updateName(String name) {
    if (!isRecording) {
      return;
    }
    _name = name;
  }

  @override
  SpanData toSpanData() => SpanData(
        context: context,
        parentSpanContext: parentSpanContext,
        resource: resource,
        instrumentationScope: instrumentationScope,
        name: _name,
        kind: kind,
        status: _status,
        startTime: _startTime,
        endTime: _endTime ?? DateTime.now().toUtc(),
        attributes: Attributes(_attributes.toMap()),
        events: List.unmodifiable(_events),
        links: List.unmodifiable(_links),
        totalRecordedEvents: _events.length,
        totalRecordedLinks: _links.length,
        totalAttributeCount: _attributes.toMap().length,
      );
}
