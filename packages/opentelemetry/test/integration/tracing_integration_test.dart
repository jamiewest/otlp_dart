import 'package:opentelemetry/opentelemetry.dart';
import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:shared/shared.dart';
import 'package:test/test.dart';

class InMemorySpanExporter implements SpanExporter {
  final List<SpanData> exportedSpans = [];
  bool isShutdown = false;
  int exportCount = 0;

  @override
  Future<ExportResult> export(List<SpanData> spans) async {
    if (isShutdown) {
      return ExportResult.failure;
    }
    exportedSpans.addAll(spans);
    exportCount++;
    return ExportResult.success;
  }

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {
    isShutdown = true;
  }

  void clear() {
    exportedSpans.clear();
    exportCount = 0;
  }
}

void main() {
  group('End-to-End Tracing Integration', () {
    late InMemorySpanExporter exporter;

    setUp(() {
      exporter = InMemorySpanExporter();
    });

    test('simple trace with single span', () async {
      final provider = SdkTracerProviderBuilder()
          .setResource(Resource({'service.name': 'test-service'}))
          .addSpanProcessor(SimpleSpanProcessor(exporter))
          .build();

      final tracer = provider.getTracer('integration-test');
      final span = tracer.startSpan('operation');
      span.setAttribute('test.key', 'test.value');
      span.addEvent(SpanEvent(name: 'event-1'));
      span.end();

      await provider.shutdown();

      expect(exporter.exportedSpans.length, equals(1));
      final spanData = exporter.exportedSpans.first;
      expect(spanData.name, equals('operation'));
      expect(spanData.attributes.toMap()['test.key'], equals('test.value'));
      expect(spanData.events.length, equals(1));
      expect(spanData.events.first.name, equals('event-1'));
    });

    test('nested trace with parent-child relationship', () async {
      final provider = SdkTracerProviderBuilder()
          .setResource(Resource({'service.name': 'test-service'}))
          .addSpanProcessor(SimpleSpanProcessor(exporter))
          .build();

      final tracer = provider.getTracer('integration-test');

      final parent = tracer.startSpan('parent-operation');
      final parentTraceId = parent.context.traceId;

      final child = Context.current.withActiveSpan(parent).execute(() {
        return tracer.startSpan('child-operation', context: Context.current);
      });

      child.end();
      parent.end();

      await provider.shutdown();

      expect(exporter.exportedSpans.length, equals(2));

      final parentData = exporter.exportedSpans
          .firstWhere((s) => s.name == 'parent-operation');
      final childData = exporter.exportedSpans
          .firstWhere((s) => s.name == 'child-operation');

      // Child should have same trace ID as parent
      expect(childData.context.traceId, equals(parentTraceId));

      // Child's parent should be the parent span
      expect(childData.parentSpanContext?.spanId, equals(parentData.context.spanId));
    });

    test('batch processor batches spans correctly', () async {
      final processor = BatchSpanProcessor(
        exporter,
        maxExportBatchSize: 10,
        maxQueueSize: 100,
        scheduledDelay: Duration(seconds: 100), // Very long to avoid timer
      );

      final provider = SdkTracerProviderBuilder()
          .setResource(Resource({'service.name': 'batch-test'}))
          .addSpanProcessor(processor)
          .build();

      final tracer = provider.getTracer('batch-test');

      // Create 25 spans
      for (var i = 0; i < 25; i++) {
        final span = tracer.startSpan('span-$i');
        span.setAttribute('index', i);
        span.end();
      }

      // Wait a bit for async operations
      await Future.delayed(Duration(milliseconds: 100));

      // Should have exported 2 batches (10 + 10) automatically
      // The remaining 5 should be in the queue
      expect(exporter.exportedSpans.length, greaterThanOrEqualTo(20));

      await provider.shutdown();

      // After shutdown, all 25 should be exported
      expect(exporter.exportedSpans.length, equals(25));
    });

    test('force flush exports all pending spans', () async {
      final processor = BatchSpanProcessor(
        exporter,
        maxExportBatchSize: 100,
        scheduledDelay: Duration(seconds: 100),
      );

      final provider = SdkTracerProviderBuilder()
          .addSpanProcessor(processor)
          .build();

      final tracer = provider.getTracer('test');

      // Create 10 spans
      for (var i = 0; i < 10; i++) {
        final span = tracer.startSpan('span-$i');
        span.end();
      }

      // Nothing should be exported yet (batch size not reached, timer not fired)
      expect(exporter.exportedSpans.length, equals(0));

      await provider.forceFlush();

      // All spans should now be exported
      expect(exporter.exportedSpans.length, equals(10));

      await provider.shutdown();
    });

    test('sampling drops spans correctly', () async {
      final provider = SdkTracerProviderBuilder()
          .setSampler(const AlwaysOffSampler())
          .addSpanProcessor(SimpleSpanProcessor(exporter))
          .build();

      final tracer = provider.getTracer('test');

      for (var i = 0; i < 10; i++) {
        final span = tracer.startSpan('span-$i');
        span.end();
      }

      await provider.shutdown();

      // No spans should be exported (all dropped by sampler)
      expect(exporter.exportedSpans.length, equals(0));
    });

    test('ratio-based sampling samples approximately correct percentage', () async {
      final provider = SdkTracerProviderBuilder()
          .setSampler(const TraceIdRatioBasedSampler(0.5)) // 50% sampling
          .addSpanProcessor(SimpleSpanProcessor(exporter))
          .build();

      final tracer = provider.getTracer('test');

      // Create many spans to get statistical significance
      for (var i = 0; i < 1000; i++) {
        final span = tracer.startSpan('span-$i');
        span.end();
      }

      await provider.shutdown();

      // Should sample roughly 50% (with some variance)
      // Allow 40-60% range for statistical variance
      expect(exporter.exportedSpans.length, greaterThan(400));
      expect(exporter.exportedSpans.length, lessThan(600));
    });

    test('distributed tracing with remote parent context', () async {
      final provider = SdkTracerProviderBuilder()
          .addSpanProcessor(SimpleSpanProcessor(exporter))
          .build();

      final tracer = provider.getTracer('test');

      // Simulate receiving a remote parent context (e.g., from HTTP headers)
      final remoteTraceId = TraceId.fromHex('00112233445566778899aabbccddeeff');
      final remoteSpanId = SpanId.fromHex('0011223344556677');
      final remoteContext = SpanContext(
        traceId: remoteTraceId,
        spanId: remoteSpanId,
        traceFlags: TraceFlags.sampled,
      );

      // Create context with remote span context
      final context = Context.root.withSpanContext(remoteContext);

      final span = tracer.startSpan('local-operation', context: context);
      span.end();

      await provider.shutdown();

      expect(exporter.exportedSpans.length, equals(1));
      final spanData = exporter.exportedSpans.first;

      // Span should inherit trace ID from remote parent
      expect(spanData.context.traceId, equals(remoteTraceId));

      // Parent should be the remote span
      expect(spanData.parentSpanContext?.spanId, equals(remoteSpanId));
    });

    test('multiple tracers share same provider configuration', () async {
      final resource = Resource({'service.name': 'multi-tracer-test'});
      final provider = SdkTracerProviderBuilder()
          .setResource(resource)
          .addSpanProcessor(SimpleSpanProcessor(exporter))
          .build();

      final tracer1 = provider.getTracer('tracer-1', version: '1.0.0');
      final tracer2 = provider.getTracer('tracer-2', version: '2.0.0');

      final span1 = tracer1.startSpan('operation-1');
      span1.end();

      final span2 = tracer2.startSpan('operation-2');
      span2.end();

      await provider.shutdown();

      expect(exporter.exportedSpans.length, equals(2));

      // Both should have same resource
      expect(exporter.exportedSpans[0].resource, equals(resource));
      expect(exporter.exportedSpans[1].resource, equals(resource));

      // But different instrumentation scopes
      expect(exporter.exportedSpans[0].instrumentationScope.name, equals('tracer-1'));
      expect(exporter.exportedSpans[0].instrumentationScope.version, equals('1.0.0'));
      expect(exporter.exportedSpans[1].instrumentationScope.name, equals('tracer-2'));
      expect(exporter.exportedSpans[1].instrumentationScope.version, equals('2.0.0'));
    });

    test('span events and attributes are preserved', () async {
      final provider = SdkTracerProviderBuilder()
          .addSpanProcessor(SimpleSpanProcessor(exporter))
          .build();

      final tracer = provider.getTracer('test');
      final span = tracer.startSpan('operation');

      span.setAttribute('str', 'value');
      span.setAttribute('int', 42);
      span.setAttribute('bool', true);
      span.setAttribute('double', 3.14);

      span.addEvent(SpanEvent(
        name: 'event-1',
        attributes: Attributes({'event.key': 'event.value'}),
      ));

      span.addEvent(SpanEvent(
        name: 'event-2',
        timestamp: DateTime.utc(2024, 1, 1),
      ));

      span.end();

      await provider.shutdown();

      expect(exporter.exportedSpans.length, equals(1));
      final spanData = exporter.exportedSpans.first;

      // Check attributes
      final attrs = spanData.attributes.toMap();
      expect(attrs['str'], equals('value'));
      expect(attrs['int'], equals(42));
      expect(attrs['bool'], equals(true));
      expect(attrs['double'], equals(3.14));

      // Check events
      expect(spanData.events.length, equals(2));
      expect(spanData.events[0].name, equals('event-1'));
      expect(spanData.events[0].attributes.toMap()['event.key'], equals('event.value'));
      expect(spanData.events[1].name, equals('event-2'));
      expect(spanData.events[1].timestamp, equals(DateTime.utc(2024, 1, 1)));
    });

    test('span links are preserved', () async {
      final provider = SdkTracerProviderBuilder()
          .addSpanProcessor(SimpleSpanProcessor(exporter))
          .build();

      final tracer = provider.getTracer('test');

      // Create a link to another span
      final linkContext = SpanContext(
        traceId: TraceId.fromHex('ffeeddccbbaa99887766554433221100'),
        spanId: SpanId.fromHex('ffeeddccbbaa9988'),
        traceFlags: TraceFlags.sampled,
      );

      final span = tracer.startSpan(
        'operation',
        links: [
          Link(
            context: linkContext,
            attributes: Attributes({'link.type': 'reference'}),
          ),
        ],
      );
      span.end();

      await provider.shutdown();

      expect(exporter.exportedSpans.length, equals(1));
      final spanData = exporter.exportedSpans.first;

      expect(spanData.links.length, equals(1));
      expect(spanData.links.first.context, equals(linkContext));
      expect(
        spanData.links.first.attributes.toMap()['link.type'],
        equals('reference'),
      );
    });

    test('multiple processors all receive spans', () async {
      final exporter1 = InMemorySpanExporter();
      final exporter2 = InMemorySpanExporter();

      final provider = SdkTracerProviderBuilder()
          .addSpanProcessor(SimpleSpanProcessor(exporter1))
          .addSpanProcessor(SimpleSpanProcessor(exporter2))
          .build();

      final tracer = provider.getTracer('test');

      for (var i = 0; i < 5; i++) {
        final span = tracer.startSpan('span-$i');
        span.end();
      }

      await provider.shutdown();

      // Both exporters should receive all spans
      expect(exporter1.exportedSpans.length, equals(5));
      expect(exporter2.exportedSpans.length, equals(5));
    });

    test('context propagation across async boundaries', () async {
      final provider = SdkTracerProviderBuilder()
          .addSpanProcessor(SimpleSpanProcessor(exporter))
          .build();

      final tracer = provider.getTracer('test');

      await Context.current.withActiveSpan(
        tracer.startSpan('parent'),
      ).execute(() async {
        final parent = Context.current.activeSpan!;

        await Future.delayed(Duration(milliseconds: 10));

        // Child created after async delay should still have parent
        final child = tracer.startSpan('child', context: Context.current);

        child.end();
        parent.end();
      });

      await provider.shutdown();

      expect(exporter.exportedSpans.length, equals(2));

      final parentData = exporter.exportedSpans
          .firstWhere((s) => s.name == 'parent');
      final childData = exporter.exportedSpans
          .firstWhere((s) => s.name == 'child');

      expect(childData.context.traceId, equals(parentData.context.traceId));
      expect(childData.parentSpanContext?.spanId, equals(parentData.context.spanId));
    });
  });
}
