import 'package:opentelemetry/opentelemetry.dart';
import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:shared/shared.dart';
import 'package:test/test.dart';

// Test exporter that records exported spans
class _TestExporter implements SpanExporter {
  final List<SpanData> exportedSpans = [];
  bool shutdownCalled = false;
  bool forceFlushCalled = false;
  ExportResult exportResult = ExportResult.success;

  @override
  Future<ExportResult> export(List<SpanData> spans) async {
    exportedSpans.addAll(spans);
    return exportResult;
  }

  @override
  Future<void> shutdown() async {
    shutdownCalled = true;
  }

  @override
  Future<void> forceFlush() async {
    forceFlushCalled = true;
  }
}

// Test readable span
class _TestSpan implements ReadableSpan {
  _TestSpan(this.spanData);

  final SpanData spanData;

  @override
  SpanData toSpanData() => spanData;

  @override
  Resource get resource => Resource({'test': 'resource'});

  @override
  InstrumentationScope get instrumentationScope =>
      const InstrumentationScope('test', version: '1.0');

  // Span interface implementations (minimal for testing)
  @override
  SpanContext get context => spanData.context;

  @override
  String get name => spanData.name;

  @override
  SpanKind get kind => spanData.kind;

  @override
  SpanContext? get parentSpanContext => spanData.parentSpanContext;

  @override
  DateTime get startTime => spanData.startTime;

  @override
  bool get isRecording => false;

  @override
  void addEvent(String name,
      {Map<String, AttributeValue> attributes = const {},
      DateTime? timestamp}) {}

  @override
  void setAttribute(String key, AttributeValue value) {}

  @override
  void setAttributes(Map<String, AttributeValue> attributes) {}

  @override
  void setStatus(Status status, {String? description}) {}

  @override
  void updateName(String name) {}

  @override
  void recordException(Object error,
      {StackTrace? stackTrace, Map<String, AttributeValue>? attributes}) {}

  @override
  void end({DateTime? endTime}) {}
}

SpanData _createSpanData(String name) {
  return SpanData(
    context: SpanContext(
      traceId: TraceId.random(),
      spanId: SpanId.random(),
    ),
    name: name,
    kind: SpanKind.internal,
    parentSpanContext: null,
    startTime: DateTime.now(),
    endTime: DateTime.now(),
    attributes: Attributes(),
    events: [],
    links: [],
    status: Status.unset,
    resource: Resource({'test': 'resource'}),
    instrumentationScope: const InstrumentationScope('test'),
    totalRecordedEvents: 0,
    totalRecordedLinks: 0,
    totalAttributeCount: 0,
  );
}

void main() {
  group('SimpleSpanProcessor', () {
    test('exports span on end', () async {
      final exporter = _TestExporter();
      final processor = SimpleSpanProcessor(exporter);
      final spanData = _createSpanData('test-span');
      final span = _TestSpan(spanData);

      await processor.onEnd(span);

      expect(exporter.exportedSpans.length, equals(1));
      expect(exporter.exportedSpans.first.name, equals('test-span'));
    });

    test('onStart does nothing', () {
      final exporter = _TestExporter();
      final processor = SimpleSpanProcessor(exporter);
      final spanData = _createSpanData('test-span');
      final span = _TestSpan(spanData);

      processor.onStart(span, Context.root);

      expect(exporter.exportedSpans, isEmpty);
    });

    test('exports multiple spans', () async {
      final exporter = _TestExporter();
      final processor = SimpleSpanProcessor(exporter);

      await processor.onEnd(_TestSpan(_createSpanData('span1')));
      await processor.onEnd(_TestSpan(_createSpanData('span2')));
      await processor.onEnd(_TestSpan(_createSpanData('span3')));

      expect(exporter.exportedSpans.length, equals(3));
      expect(exporter.exportedSpans[0].name, equals('span1'));
      expect(exporter.exportedSpans[1].name, equals('span2'));
      expect(exporter.exportedSpans[2].name, equals('span3'));
    });

    test('does not export after shutdown', () async {
      final exporter = _TestExporter();
      final processor = SimpleSpanProcessor(exporter);

      await processor.shutdown();
      await processor.onEnd(_TestSpan(_createSpanData('test-span')));

      expect(exporter.exportedSpans, isEmpty);
    });

    test('shutdown calls exporter shutdown', () async {
      final exporter = _TestExporter();
      final processor = SimpleSpanProcessor(exporter);

      await processor.shutdown();

      expect(exporter.shutdownCalled, isTrue);
    });

    test('shutdown is idempotent', () async {
      final exporter = _TestExporter();
      final processor = SimpleSpanProcessor(exporter);

      await processor.shutdown();
      await processor.shutdown();
      await processor.shutdown();

      expect(exporter.shutdownCalled, isTrue);
    });

    test('forceFlush calls exporter forceFlush', () async {
      final exporter = _TestExporter();
      final processor = SimpleSpanProcessor(exporter);

      await processor.forceFlush();

      expect(exporter.forceFlushCalled, isTrue);
    });

    test('handles export failure gracefully', () async {
      final exporter = _TestExporter();
      exporter.exportResult = ExportResult.failure;
      final processor = SimpleSpanProcessor(exporter);

      // Should not throw
      await processor.onEnd(_TestSpan(_createSpanData('test-span')));

      expect(exporter.exportedSpans.length, equals(1));
    });
  });

  group('MultiSpanProcessor', () {
    test('calls onStart on all processors', () {
      final exporter1 = _TestExporter();
      final exporter2 = _TestExporter();
      final processor = MultiSpanProcessor([
        SimpleSpanProcessor(exporter1),
        SimpleSpanProcessor(exporter2),
      ]);
      final spanData = _createSpanData('test-span');
      final span = _TestSpan(spanData);

      processor.onStart(span, Context.root);

      // SimpleSpanProcessor doesn't do anything on start, just verify no errors
    });

    test('calls onEnd on all processors', () async {
      final exporter1 = _TestExporter();
      final exporter2 = _TestExporter();
      final processor = MultiSpanProcessor([
        SimpleSpanProcessor(exporter1),
        SimpleSpanProcessor(exporter2),
      ]);
      final spanData = _createSpanData('test-span');
      final span = _TestSpan(spanData);

      await processor.onEnd(span);

      expect(exporter1.exportedSpans.length, equals(1));
      expect(exporter2.exportedSpans.length, equals(1));
      expect(exporter1.exportedSpans.first.name, equals('test-span'));
      expect(exporter2.exportedSpans.first.name, equals('test-span'));
    });

    test('calls shutdown on all processors', () async {
      final exporter1 = _TestExporter();
      final exporter2 = _TestExporter();
      final processor = MultiSpanProcessor([
        SimpleSpanProcessor(exporter1),
        SimpleSpanProcessor(exporter2),
      ]);

      await processor.shutdown();

      expect(exporter1.shutdownCalled, isTrue);
      expect(exporter2.shutdownCalled, isTrue);
    });

    test('calls forceFlush on all processors', () async {
      final exporter1 = _TestExporter();
      final exporter2 = _TestExporter();
      final processor = MultiSpanProcessor([
        SimpleSpanProcessor(exporter1),
        SimpleSpanProcessor(exporter2),
      ]);

      await processor.forceFlush();

      expect(exporter1.forceFlushCalled, isTrue);
      expect(exporter2.forceFlushCalled, isTrue);
    });

    test('works with empty processor list', () async {
      final processor = MultiSpanProcessor([]);
      final spanData = _createSpanData('test-span');
      final span = _TestSpan(spanData);

      processor.onStart(span, Context.root);
      await processor.onEnd(span);
      await processor.forceFlush();
      await processor.shutdown();

      // Should complete without errors
    });

    test('handles mix of processor types', () async {
      final exporter1 = _TestExporter();
      final exporter2 = _TestExporter();
      final exporter3 = _TestExporter();

      final processor = MultiSpanProcessor([
        SimpleSpanProcessor(exporter1),
        MultiSpanProcessor([
          SimpleSpanProcessor(exporter2),
          SimpleSpanProcessor(exporter3),
        ]),
      ]);

      final spanData = _createSpanData('test-span');
      final span = _TestSpan(spanData);

      await processor.onEnd(span);

      expect(exporter1.exportedSpans.length, equals(1));
      expect(exporter2.exportedSpans.length, equals(1));
      expect(exporter3.exportedSpans.length, equals(1));
    });

    test('continues processing even if one processor fails', () async {
      final exporter1 = _TestExporter();
      exporter1.exportResult = ExportResult.failure;
      final exporter2 = _TestExporter();
      final processor = MultiSpanProcessor([
        SimpleSpanProcessor(exporter1),
        SimpleSpanProcessor(exporter2),
      ]);

      final spanData = _createSpanData('test-span');
      final span = _TestSpan(spanData);

      await processor.onEnd(span);

      expect(exporter1.exportedSpans.length, equals(1));
      expect(exporter2.exportedSpans.length, equals(1));
    });
  });
}
