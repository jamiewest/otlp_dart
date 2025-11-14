import 'dart:async';

import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:opentelemetry_shared/opentelemetry_shared.dart';

import '../resource/resource.dart';
import 'id_generator.dart';
import 'sampler.dart';
import 'sdk_span.dart';
import 'span_processor.dart';

class SdkTracerProvider implements TracerProvider {
  SdkTracerProvider({
    required this.resource,
    required this.sampler,
    required this.idGenerator,
    required SpanProcessor spanProcessor,
  }) : _spanProcessor = spanProcessor;

  final Resource resource;
  final Sampler sampler;
  final IdGenerator idGenerator;
  final SpanProcessor _spanProcessor;
  final Map<InstrumentationScope, SdkTracer> _tracers = {};
  bool _isShutdown = false;

  @override
  Tracer getTracer(String name, {String? version, String? schemaUrl}) {
    final scope =
        InstrumentationScope(name, version: version, schemaUrl: schemaUrl);
    return _tracers.putIfAbsent(scope, () => SdkTracer(this, scope));
  }

  @override
  Future<void> forceFlush() => _spanProcessor.forceFlush();

  @override
  Future<void> shutdown() async {
    if (_isShutdown) {
      return;
    }
    _isShutdown = true;
    await _spanProcessor.shutdown();
  }

  Future<void> _onSpanEnded(SdkSpan span) => _spanProcessor.onEnd(span);
}

class SdkTracer extends Tracer {
  SdkTracer(this._provider, this._scope);

  final SdkTracerProvider _provider;
  final InstrumentationScope _scope;

  @override
  Span startSpan(
    String name, {
    Context? context,
    SpanKind kind = SpanKind.internal,
    Map<String, AttributeValue> attributes = const {},
    List<Link> links = const [],
    DateTime? startTime,
  }) {
    if (_provider._isShutdown) {
      return NoopSpan();
    }

    final parentContext = context ?? Context.current;
    final parentSpan = parentContext.activeSpan;
    final SpanContext? remoteParent = parentContext.spanContext;
    final SpanContext? parentSpanContext =
        parentSpan?.context ?? remoteParent;

    final traceId = parentSpanContext?.traceId.isValid == true
        ? parentSpanContext!.traceId
        : _provider.idGenerator.newTraceId();
    final spanId = _provider.idGenerator.newSpanId();

    final samplingOptions = SamplingOptions(
      parentContext: parentContext,
      traceId: traceId,
      spanName: name,
      spanKind: kind,
      links: links,
      attributes: attributes,
    );

    final samplingResult = _provider.sampler.shouldSample(samplingOptions);

    if (samplingResult.decision == SamplingDecision.drop) {
      return NoopSpan();
    }

    final traceFlags = samplingResult.decision ==
            SamplingDecision.recordAndSample
        ? TraceFlags.sampled
        : TraceFlags.none;

    final spanContext = SpanContext(
      traceId: traceId,
      spanId: spanId,
      traceFlags: traceFlags,
      traceState: samplingResult.traceState ??
          parentSpanContext?.traceState ??
          TraceState.empty,
    );

    final attributesSet = Attributes(attributes);
    attributesSet.addAll(samplingResult.attributes);

    final resolvedParent =
        parentSpanContext?.isValid == true ? parentSpanContext : null;

    final span = SdkSpan(
      context: spanContext,
      parentSpanContext: resolvedParent,
      name: name,
      kind: kind,
      attributes: attributesSet,
      links: links,
      startTime: (startTime ?? DateTime.now().toUtc()),
      resource: _provider.resource,
      instrumentationScope: _scope,
      onEnded: (span) => unawaited(_provider._onSpanEnded(span)),
    );

    _provider._spanProcessor.onStart(span, parentContext);
    return span;
  }
}
