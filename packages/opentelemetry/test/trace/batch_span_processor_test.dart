import 'dart:async';

import 'package:opentelemetry/opentelemetry.dart';
import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:shared/shared.dart';
import 'package:test/test.dart';

// Test exporter that records exported spans
class _TestExporter implements SpanExporter {
  final List<List<SpanData>> exportCalls = [];
  final List<SpanData> exportedSpans = [];
  bool shutdownCalled = false;
  bool forceFlushCalled = false;
  ExportResult exportResult = ExportResult.success;
  Duration? exportDelay;
  Completer<void>? blockingCompleter;

  @override
  Future<ExportResult> export(List<SpanData> spans) async {
    if (blockingCompleter != null) {
      await blockingCompleter!.future;
    }
    if (exportDelay != null) {
      await Future.delayed(exportDelay!);
    }
    exportCalls.add(List.from(spans));
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

  void reset() {
    exportCalls.clear();
    exportedSpans.clear();
    shutdownCalled = false;
    forceFlushCalled = false;
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
  void setAttribute(String key, AttributeValue? value) {}

  @override
  void setStatus(Status status) {}

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
  group('BatchSpanProcessor', () {
    test('batches spans before exporting', () async {
      final exporter = _TestExporter();
      final processor = BatchSpanProcessor(
        exporter,
        maxExportBatchSize: 3,
        scheduledDelay: const Duration(seconds: 10), // Long delay
      );

      // Add 2 spans - should not export yet
      await processor.onEnd(_TestSpan(_createSpanData('span1')));
      await processor.onEnd(_TestSpan(_createSpanData('span2')));

      expect(exporter.exportCalls, isEmpty);

      // Add 3rd span - should trigger batch export
      await processor.onEnd(_TestSpan(_createSpanData('span3')));

      expect(exporter.exportCalls.length, equals(1));
      expect(exporter.exportedSpans.length, equals(3));
      expect(exporter.exportedSpans[0].name, equals('span1'));
      expect(exporter.exportedSpans[1].name, equals('span2'));
      expect(exporter.exportedSpans[2].name, equals('span3'));

      await processor.shutdown();
    });

    test('exports on scheduled timer', () async {
      final exporter = _TestExporter();
      final processor = BatchSpanProcessor(
        exporter,
        maxExportBatchSize: 100,
        scheduledDelay: const Duration(milliseconds: 100),
      );

      await processor.onEnd(_TestSpan(_createSpanData('span1')));
      await processor.onEnd(_TestSpan(_createSpanData('span2')));

      // Should not export immediately
      expect(exporter.exportCalls, isEmpty);

      // Wait for timer
      await Future.delayed(const Duration(milliseconds: 150));

      expect(exporter.exportCalls.length, equals(1));
      expect(exporter.exportedSpans.length, equals(2));

      await processor.shutdown();
    });

    test('respects maxQueueSize and drops spans when full', () async {
      final exporter = _TestExporter();
      final processor = BatchSpanProcessor(
        exporter,
        maxQueueSize: 3,
        maxExportBatchSize: 10,
        scheduledDelay: const Duration(seconds: 10),
      );

      // Fill queue
      await processor.onEnd(_TestSpan(_createSpanData('span1')));
      await processor.onEnd(_TestSpan(_createSpanData('span2')));
      await processor.onEnd(_TestSpan(_createSpanData('span3')));

      // This should be dropped
      await processor.onEnd(_TestSpan(_createSpanData('span4')));

      await processor.forceFlush();

      // Should only have 3 spans
      expect(exporter.exportedSpans.length, equals(3));
      expect(exporter.exportedSpans.any((s) => s.name == 'span4'), isFalse);

      await processor.shutdown();
    });

    test('forceFlush exports all pending spans', () async {
      final exporter = _TestExporter();
      final processor = BatchSpanProcessor(
        exporter,
        maxExportBatchSize: 100,
        scheduledDelay: const Duration(seconds: 10),
      );

      await processor.onEnd(_TestSpan(_createSpanData('span1')));
      await processor.onEnd(_TestSpan(_createSpanData('span2')));
      await processor.onEnd(_TestSpan(_createSpanData('span3')));

      expect(exporter.exportCalls, isEmpty);

      await processor.forceFlush();

      expect(exporter.exportCalls.length, equals(1));
      expect(exporter.exportedSpans.length, equals(3));
      expect(exporter.forceFlushCalled, isTrue);

      await processor.shutdown();
    });

    test('forceFlush exports in batches', () async {
      final exporter = _TestExporter();
      final processor = BatchSpanProcessor(
        exporter,
        maxExportBatchSize: 2,
        scheduledDelay: const Duration(seconds: 10),
      );

      // Add 5 spans
      for (var i = 1; i <= 5; i++) {
        await processor.onEnd(_TestSpan(_createSpanData('span$i')));
      }

      await processor.forceFlush();

      // Should have 3 export calls: 2 + 2 + 1
      expect(exporter.exportCalls.length, equals(3));
      expect(exporter.exportCalls[0].length, equals(2));
      expect(exporter.exportCalls[1].length, equals(2));
      expect(exporter.exportCalls[2].length, equals(1));
      expect(exporter.exportedSpans.length, equals(5));

      await processor.shutdown();
    });

    test('shutdown exports remaining spans', () async {
      final exporter = _TestExporter();
      final processor = BatchSpanProcessor(
        exporter,
        maxExportBatchSize: 100,
        scheduledDelay: const Duration(seconds: 10),
      );

      await processor.onEnd(_TestSpan(_createSpanData('span1')));
      await processor.onEnd(_TestSpan(_createSpanData('span2')));

      expect(exporter.exportCalls, isEmpty);

      await processor.shutdown();

      expect(exporter.exportedSpans.length, equals(2));
      expect(exporter.shutdownCalled, isTrue);
    });

    test('shutdown stops timer', () async {
      final exporter = _TestExporter();
      final processor = BatchSpanProcessor(
        exporter,
        scheduledDelay: const Duration(milliseconds: 50),
      );

      await processor.onEnd(_TestSpan(_createSpanData('span1')));
      await processor.shutdown();

      exporter.reset();

      // Wait longer than timer period
      await Future.delayed(const Duration(milliseconds: 100));

      // Should not have exported again
      expect(exporter.exportCalls, isEmpty);
    });

    test('does not accept spans after shutdown', () async {
      final exporter = _TestExporter();
      final processor = BatchSpanProcessor(
        exporter,
        scheduledDelay: const Duration(seconds: 10),
      );

      await processor.shutdown();

      await processor.onEnd(_TestSpan(_createSpanData('span1')));

      expect(exporter.exportedSpans, isEmpty);
    });

    test('shutdown is idempotent', () async {
      final exporter = _TestExporter();
      final processor = BatchSpanProcessor(
        exporter,
        scheduledDelay: const Duration(seconds: 10),
      );

      await processor.onEnd(_TestSpan(_createSpanData('span1')));

      await processor.shutdown();
      await processor.shutdown();
      await processor.shutdown();

      expect(exporter.exportedSpans.length, equals(1));
    });

    test('forceFlush does nothing after shutdown', () async {
      final exporter = _TestExporter();
      final processor = BatchSpanProcessor(
        exporter,
        scheduledDelay: const Duration(seconds: 10),
      );

      await processor.shutdown();

      exporter.reset();
      await processor.forceFlush();

      expect(exporter.forceFlushCalled, isFalse);
    });

    test('handles export timeout', () async {
      final exporter = _TestExporter();
      exporter.exportDelay = const Duration(milliseconds: 100);

      final processor = BatchSpanProcessor(
        exporter,
        maxExportBatchSize: 2,
        scheduledDelay: const Duration(seconds: 10),
        exportTimeout: const Duration(milliseconds: 50),
      );

      await processor.onEnd(_TestSpan(_createSpanData('span1')));
      await processor.onEnd(_TestSpan(_createSpanData('span2')));

      // Should timeout but not throw
      await processor.forceFlush();

      await processor.shutdown();
    });

    test('exports multiple batches when batch size is reached', () async {
      final exporter = _TestExporter();
      final processor = BatchSpanProcessor(
        exporter,
        maxExportBatchSize: 2,
        scheduledDelay: const Duration(seconds: 10),
      );

      // Add 5 spans - should trigger 2 exports (2 + 2)
      for (var i = 1; i <= 5; i++) {
        await processor.onEnd(_TestSpan(_createSpanData('span$i')));
      }

      expect(exporter.exportCalls.length, equals(2));
      expect(exporter.exportedSpans.length, equals(4));

      await processor.shutdown();

      // Shutdown should export the remaining 1 span
      expect(exporter.exportedSpans.length, equals(5));
    });

    test('uses default configuration', () async {
      final exporter = _TestExporter();
      final processor = BatchSpanProcessor(exporter);

      await processor.onEnd(_TestSpan(_createSpanData('span1')));
      await processor.forceFlush();

      expect(exporter.exportedSpans.length, equals(1));

      await processor.shutdown();
    });

    test('timer export does not interfere with manual export', () async {
      final exporter = _TestExporter();
      final processor = BatchSpanProcessor(
        exporter,
        maxExportBatchSize: 10,
        scheduledDelay: const Duration(milliseconds: 50),
      );

      await processor.onEnd(_TestSpan(_createSpanData('span1')));
      await processor.onEnd(_TestSpan(_createSpanData('span2')));

      // Manually flush
      await processor.forceFlush();

      expect(exporter.exportCalls.length, equals(1));
      exporter.reset();

      // Wait for timer (should not export anything)
      await Future.delayed(const Duration(milliseconds: 100));

      expect(exporter.exportCalls, isEmpty);

      await processor.shutdown();
    });

    test('handles concurrent span additions', () async {
      final exporter = _TestExporter();
      final processor = BatchSpanProcessor(
        exporter,
        maxExportBatchSize: 100,
        scheduledDelay: const Duration(seconds: 10),
      );

      // Add spans concurrently
      final futures = <Future>[];
      for (var i = 1; i <= 10; i++) {
        futures.add(processor.onEnd(_TestSpan(_createSpanData('span$i'))));
      }

      await Future.wait(futures);
      await processor.forceFlush();

      expect(exporter.exportedSpans.length, equals(10));

      await processor.shutdown();
    });
  });
}
