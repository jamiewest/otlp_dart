import 'package:opentelemetry/opentelemetry.dart';
import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:shared/shared.dart';
import 'package:test/test.dart';

// Mock implementations for testing
class InMemorySpanExporter implements SpanExporter {
  final List<SpanData> exportedSpans = [];
  bool isShutdown = false;

  @override
  Future<ExportResult> export(List<SpanData> spans) async {
    if (isShutdown) {
      return ExportResult.failure;
    }
    exportedSpans.addAll(spans);
    return ExportResult.success;
  }

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {
    isShutdown = true;
  }
}

class TestIdGenerator implements IdGenerator {
  int _traceIdCounter = 1;
  int _spanIdCounter = 1;

  @override
  TraceId newTraceId() {
    final id = _traceIdCounter.toRadixString(16).padLeft(32, '0');
    _traceIdCounter++;
    return TraceId.fromHex(id);
  }

  @override
  SpanId newSpanId() {
    final id = _spanIdCounter.toRadixString(16).padLeft(16, '0');
    _spanIdCounter++;
    return SpanId.fromHex(id);
  }
}

void main() {
  group('SdkTracerProviderBuilder', () {
    test('builds provider with default configuration', () {
      final provider = SdkTracerProviderBuilder().build();

      expect(provider.resource, equals(Resource.defaultResource()));
      expect(provider.sampler, isA<AlwaysOnSampler>());
      expect(provider.idGenerator, isA<RandomIdGenerator>());
    });

    test('builds provider with custom resource', () {
      final resource = Resource({'service.name': 'test-service'});
      final provider = SdkTracerProviderBuilder()
          .setResource(resource)
          .build();

      expect(provider.resource, equals(resource));
    });

    test('builds provider with custom sampler', () {
      final sampler = const AlwaysOffSampler();
      final provider = SdkTracerProviderBuilder()
          .setSampler(sampler)
          .build();

      expect(provider.sampler, equals(sampler));
    });

    test('builds provider with custom ID generator', () {
      final idGenerator = TestIdGenerator();
      final provider = SdkTracerProviderBuilder()
          .setIdGenerator(idGenerator)
          .build();

      expect(provider.idGenerator, equals(idGenerator));
    });

    test('builds provider with single span processor', () {
      final exporter = InMemorySpanExporter();
      final processor = SimpleSpanProcessor(exporter);
      final provider = SdkTracerProviderBuilder()
          .addSpanProcessor(processor)
          .build();

      final tracer = provider.getTracer('test');
      final span = tracer.startSpan('test-span');
      span.end();

      expect(exporter.exportedSpans.length, equals(1));
    });

    test('builds provider with multiple span processors', () {
      final exporter1 = InMemorySpanExporter();
      final exporter2 = InMemorySpanExporter();
      final provider = SdkTracerProviderBuilder()
          .addSpanProcessor(SimpleSpanProcessor(exporter1))
          .addSpanProcessor(SimpleSpanProcessor(exporter2))
          .build();

      final tracer = provider.getTracer('test');
      final span = tracer.startSpan('test-span');
      span.end();

      expect(exporter1.exportedSpans.length, equals(1));
      expect(exporter2.exportedSpans.length, equals(1));
    });

    test('builds provider with no processors uses noop', () {
      final provider = SdkTracerProviderBuilder().build();
      final tracer = provider.getTracer('test');
      final span = tracer.startSpan('test-span');
      span.end();

      // Should not throw, noop exporter just discards spans
    });
  });

  group('SdkTracerProvider', () {
    late InMemorySpanExporter exporter;
    late SdkTracerProvider provider;

    setUp(() {
      exporter = InMemorySpanExporter();
      provider = SdkTracerProviderBuilder()
          .addSpanProcessor(SimpleSpanProcessor(exporter))
          .build();
    });

    test('getTracer returns same instance for same scope', () {
      final tracer1 = provider.getTracer('test', version: '1.0.0');
      final tracer2 = provider.getTracer('test', version: '1.0.0');

      expect(identical(tracer1, tracer2), isTrue);
    });

    test('getTracer returns different instances for different scopes', () {
      final tracer1 = provider.getTracer('test1');
      final tracer2 = provider.getTracer('test2');

      expect(identical(tracer1, tracer2), isFalse);
    });

    test('getTracer includes version in scope', () {
      final tracer1 = provider.getTracer('test', version: '1.0.0');
      final tracer2 = provider.getTracer('test', version: '2.0.0');

      expect(identical(tracer1, tracer2), isFalse);
    });

    test('forceFlush delegates to span processor', () async {
      final exporter = InMemorySpanExporter();
      final processor = BatchSpanProcessor(
        exporter,
        maxExportBatchSize: 10,
        scheduledDelay: Duration(seconds: 100),
      );
      final provider = SdkTracerProviderBuilder()
          .addSpanProcessor(processor)
          .build();

      final tracer = provider.getTracer('test');
      for (var i = 0; i < 5; i++) {
        final span = tracer.startSpan('test-$i');
        span.end();
      }

      await provider.forceFlush();
      await processor.shutdown();

      expect(exporter.exportedSpans.length, equals(5));
    });

    test('shutdown prevents new spans after shutdown', () async {
      final tracer = provider.getTracer('test');

      await provider.shutdown();

      final span = tracer.startSpan('test-span');
      expect(span, isA<NoopSpan>());
    });

    test('shutdown is idempotent', () async {
      await provider.shutdown();
      await provider.shutdown(); // Should not throw
    });

    test('shutdown exports remaining spans', () async {
      final exporter = InMemorySpanExporter();
      final processor = BatchSpanProcessor(
        exporter,
        maxExportBatchSize: 100,
        scheduledDelay: Duration(seconds: 100),
      );
      final provider = SdkTracerProviderBuilder()
          .addSpanProcessor(processor)
          .build();

      final tracer = provider.getTracer('test');
      for (var i = 0; i < 5; i++) {
        final span = tracer.startSpan('test-$i');
        span.end();
      }

      await provider.shutdown();

      expect(exporter.exportedSpans.length, equals(5));
    });
  });

  group('SdkTracer', () {
    late InMemorySpanExporter exporter;
    late SdkTracerProvider provider;
    late Tracer tracer;

    setUp(() {
      exporter = InMemorySpanExporter();
      provider = SdkTracerProviderBuilder()
          .addSpanProcessor(SimpleSpanProcessor(exporter))
          .setIdGenerator(TestIdGenerator())
          .build();
      tracer = provider.getTracer('test-tracer', version: '1.0.0');
    });

    tearDown(() async {
      await provider.shutdown();
    });

    test('creates span with correct name', () {
      final span = tracer.startSpan('test-span');
      span.end();

      expect(exporter.exportedSpans.length, equals(1));
      expect(exporter.exportedSpans.first.name, equals('test-span'));
    });

    test('creates span with correct kind', () {
      final span = tracer.startSpan('test', kind: SpanKind.client);
      span.end();

      expect(exporter.exportedSpans.first.kind, equals(SpanKind.client));
    });

    test('creates span with attributes', () {
      final span = tracer.startSpan(
        'test',
        attributes: {'key1': 'value1', 'key2': 123},
      );
      span.end();

      final attrs = exporter.exportedSpans.first.attributes.toMap();
      expect(attrs['key1'], equals('value1'));
      expect(attrs['key2'], equals(123));
    });

    test('creates span with links', () {
      final linkContext = SpanContext(
        traceId: TraceId.fromHex('00112233445566778899aabbccddeeff'),
        spanId: SpanId.fromHex('0011223344556677'),
        traceFlags: TraceFlags.sampled,
      );
      final link = Link(context: linkContext);

      final span = tracer.startSpan('test', links: [link]);
      span.end();

      expect(exporter.exportedSpans.first.links.length, equals(1));
      expect(
        exporter.exportedSpans.first.links.first.context,
        equals(linkContext),
      );
    });

    test('creates span with custom start time', () {
      final startTime = DateTime.utc(2024, 1, 1);
      final span = tracer.startSpan('test', startTime: startTime);
      span.end();

      expect(exporter.exportedSpans.first.startTime, equals(startTime));
    });

    test('creates root span with new trace ID', () {
      final span = tracer.startSpan('test');
      span.end();

      final spanData = exporter.exportedSpans.first;
      expect(spanData.context.traceId.isValid, isTrue);
      expect(spanData.parentSpanContext, isNull);
    });

    test('creates child span with parent trace ID', () {
      final parent = tracer.startSpan('parent');
      final parentContext = parent.context;

      final child = Context.current
          .withActiveSpan(parent)
          .execute(() => tracer.startSpan('child', context: Context.current));

      parent.end();
      child.end();

      expect(exporter.exportedSpans.length, equals(2));
      final childData = exporter.exportedSpans
          .firstWhere((s) => s.name == 'child');
      expect(childData.context.traceId, equals(parentContext.traceId));
      expect(childData.parentSpanContext?.spanId, equals(parentContext.spanId));
    });

    test('respects sampler decision to drop', () {
      final provider = SdkTracerProviderBuilder()
          .addSpanProcessor(SimpleSpanProcessor(exporter))
          .setSampler(const AlwaysOffSampler())
          .build();
      final tracer = provider.getTracer('test');

      final span = tracer.startSpan('test');
      expect(span, isA<NoopSpan>());

      await provider.shutdown();
      expect(exporter.exportedSpans.length, equals(0));
    });

    test('respects sampler decision to record and sample', () {
      final span = tracer.startSpan('test');
      span.end();

      expect(exporter.exportedSpans.length, equals(1));
      expect(
        exporter.exportedSpans.first.context.traceFlags,
        equals(TraceFlags.sampled),
      );
    });

    test('includes resource in span data', () {
      final resource = Resource({'service.name': 'my-service'});
      final provider = SdkTracerProviderBuilder()
          .setResource(resource)
          .addSpanProcessor(SimpleSpanProcessor(exporter))
          .build();
      final tracer = provider.getTracer('test');

      final span = tracer.startSpan('test');
      span.end();

      await provider.shutdown();

      expect(exporter.exportedSpans.first.resource, equals(resource));
    });

    test('includes instrumentation scope in span data', () {
      final span = tracer.startSpan('test');
      span.end();

      final scope = exporter.exportedSpans.first.instrumentationScope;
      expect(scope.name, equals('test-tracer'));
      expect(scope.version, equals('1.0.0'));
    });

    test('merges sampler attributes with span attributes', () {
      final sampler = const TraceIdRatioBasedSampler(1.0);
      final provider = SdkTracerProviderBuilder()
          .setSampler(sampler)
          .addSpanProcessor(SimpleSpanProcessor(exporter))
          .build();
      final tracer = provider.getTracer('test');

      final span = tracer.startSpan('test', attributes: {'user-attr': 'value'});
      span.end();

      await provider.shutdown();

      final attrs = exporter.exportedSpans.first.attributes.toMap();
      expect(attrs['user-attr'], equals('value'));
    });
  });
}
