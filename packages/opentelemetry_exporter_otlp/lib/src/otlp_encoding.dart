import 'dart:typed_data';

import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:opentelemetry/opentelemetry.dart' as otel_sdk;
import 'package:otlp_dart/src/proto/opentelemetry/proto/collector/logs/v1/logs_service.pb.dart'
    as otlp_logs_service;
import 'package:otlp_dart/src/proto/opentelemetry/proto/collector/metrics/v1/metrics_service.pb.dart'
    as otlp_metrics_service;
import 'package:otlp_dart/src/proto/opentelemetry/proto/collector/trace/v1/trace_service.pb.dart'
    as otlp_trace_service;
import 'package:otlp_dart/src/proto/opentelemetry/proto/common/v1/common.pb.dart'
    as otlp_common;
import 'package:otlp_dart/src/proto/opentelemetry/proto/logs/v1/logs.pb.dart'
    as otlp_logs;
import 'package:otlp_dart/src/proto/opentelemetry/proto/metrics/v1/metrics.pb.dart'
    as otlp_metrics;
import 'package:otlp_dart/src/proto/opentelemetry/proto/resource/v1/resource.pb.dart'
    as otlp_resource;
import 'package:otlp_dart/src/proto/opentelemetry/proto/trace/v1/trace.pb.dart'
    as otlp_trace;
import 'package:shared/shared.dart';

otlp_trace_service.ExportTraceServiceRequest buildTraceRequest(
        List<otel_sdk.SpanData> spans) =>
    otlp_trace_service.ExportTraceServiceRequest(
      resourceSpans: _groupByResourceAndScope(
        spans,
        (span) => span.resource,
        (span) => span.instrumentationScope,
      ).entries
          .map((entry) => _toResourceSpans(entry.key, entry.value))
          .toList(),
    );

otlp_metrics_service.ExportMetricsServiceRequest buildMetricRequest(
        List<otel_sdk.MetricData> metrics) =>
    otlp_metrics_service.ExportMetricsServiceRequest(
      resourceMetrics: _groupByResourceAndScope(
        metrics,
        (metric) => metric.resource,
        (metric) => metric.instrumentationScope,
      ).entries
          .map((entry) => _toResourceMetrics(entry.key, entry.value))
          .toList(),
    );

otlp_logs_service.ExportLogsServiceRequest buildLogRequest(
        List<otel_sdk.LogRecord> records) =>
    otlp_logs_service.ExportLogsServiceRequest(
      resourceLogs: _groupByResourceAndScope(
        records,
        (record) => record.resource,
        (record) => record.instrumentationScope,
      ).entries
          .map((entry) => _toResourceLogs(entry.key, entry.value))
          .toList(),
    );

Map<otel_sdk.Resource, Map<InstrumentationScope, List<T>>>
    _groupByResourceAndScope<T>(
  Iterable<T> values,
  otel_sdk.Resource Function(T value) resourceSelector,
  InstrumentationScope Function(T value) scopeSelector,
) {
  final result = <otel_sdk.Resource, Map<InstrumentationScope, List<T>>>{};
  for (final value in values) {
    final resource = resourceSelector(value);
    final scope = scopeSelector(value);
    final scopeGroup =
        result.putIfAbsent(resource, () => <InstrumentationScope, List<T>>{});
    final bucket = scopeGroup.putIfAbsent(scope, () => <T>[]);
    bucket.add(value);
  }
  return result;
}

otlp_trace.ResourceSpans _toResourceSpans(
  otel_sdk.Resource resource,
  Map<InstrumentationScope, List<otel_sdk.SpanData>> scopedSpans,
) {
  return otlp_trace.ResourceSpans(
    resource: _toResource(resource),
    scopeSpans: scopedSpans.entries
        .map((entry) => otlp_trace.ScopeSpans(
              scope: _toInstrumentationScope(entry.key),
              schemaUrl: entry.key.schemaUrl ?? '',
              spans: entry.value.map(_toProtoSpan).toList(),
            ))
        .toList(),
  );
}

otlp_metrics.ResourceMetrics _toResourceMetrics(
  otel_sdk.Resource resource,
  Map<InstrumentationScope, List<otel_sdk.MetricData>> scopedMetrics,
) {
  return otlp_metrics.ResourceMetrics(
    resource: _toResource(resource),
    scopeMetrics: scopedMetrics.entries
        .map((entry) => otlp_metrics.ScopeMetrics(
              scope: _toInstrumentationScope(entry.key),
              schemaUrl: entry.key.schemaUrl ?? '',
              metrics: entry.value.map(_toProtoMetric).toList(),
            ))
        .toList(),
  );
}

otlp_logs.ResourceLogs _toResourceLogs(
  otel_sdk.Resource resource,
  Map<InstrumentationScope, List<otel_sdk.LogRecord>> scopedLogs,
) {
  return otlp_logs.ResourceLogs(
    resource: _toResource(resource),
    scopeLogs: scopedLogs.entries
        .map((entry) => otlp_logs.ScopeLogs(
              scope: _toInstrumentationScope(entry.key),
              schemaUrl: entry.key.schemaUrl ?? '',
              logRecords: entry.value.map(_toProtoLogRecord).toList(),
            ))
        .toList(),
  );
}

otlp_trace.Span _toProtoSpan(otel_sdk.SpanData span) {
  final spanProto = otlp_trace.Span(
    traceId: _hexToBytes(span.context.traceId.value),
    spanId: _hexToBytes(span.context.spanId.value),
    name: span.name,
    kind: _mapSpanKind(span.kind),
    startTimeUnixNano: _toUnixNanos(span.startTime),
    endTimeUnixNano: _toUnixNanos(span.endTime),
    attributes: _toKeyValues(span.attributes.toMap()),
    events: span.events.map(_toProtoEvent).toList(),
    links: span.links.map(_toProtoLink).toList(),
    status: _toProtoStatus(span.status),
    droppedAttributesCount: 0,
    droppedEventsCount: 0,
    droppedLinksCount: 0,
    flags: span.context.traceFlags.value,
  );

  final parent = span.parentSpanContext;
  if (parent != null && parent.isValid) {
    spanProto.parentSpanId = _hexToBytes(parent.spanId.value);
  }

  final traceState = span.context.traceState;
  if (!traceState.isEmpty) {
    spanProto.traceState =
        traceState.entries.map((e) => '${e.key}=${e.value}').join(',');
  }

  return spanProto;
}

otlp_trace.Span_Event _toProtoEvent(SpanEvent event) => otlp_trace.Span_Event(
      name: event.name,
      timeUnixNano: _toUnixNanos(event.timestamp),
      attributes: _toKeyValues(event.attributes.toMap()),
      droppedAttributesCount: 0,
    );

otlp_trace.Span_Link _toProtoLink(Link link) {
  final proto = otlp_trace.Span_Link(
    traceId: _hexToBytes(link.context.traceId.value),
    spanId: _hexToBytes(link.context.spanId.value),
    attributes: _toKeyValues(link.attributes.toMap()),
    droppedAttributesCount: 0,
  );
  final traceState = link.context.traceState;
  if (!traceState.isEmpty) {
    proto.traceState = traceState.entries.map((e) => '${e.key}=${e.value}').join(',');
  }
  return proto;
}

otlp_trace.Status _toProtoStatus(Status status) {
  final proto = otlp_trace.Status(
    code: _mapStatusCode(status.statusCode),
  );
  if (status.description != null) {
    proto.message = status.description!;
  }
  return proto;
}

otlp_metrics.Metric _toProtoMetric(otel_sdk.MetricData metric) {
  final descriptor = metric.descriptor;
  final metricProto = otlp_metrics.Metric(
    name: descriptor.name,
    description: descriptor.description ?? '',
    unit: descriptor.unit ?? '',
  );

  switch (descriptor.type) {
    case otel_sdk.MetricType.sum:
      metricProto.sum = otlp_metrics.Sum(
        isMonotonic: true,
        aggregationTemporality: otlp_metrics.AggregationTemporality
            .AGGREGATION_TEMPORALITY_CUMULATIVE,
        dataPoints: metric.points.map(_toNumberDataPoint).toList(),
      );
      break;
    case otel_sdk.MetricType.upDownSum:
      metricProto.sum = otlp_metrics.Sum(
        isMonotonic: false,
        aggregationTemporality: otlp_metrics.AggregationTemporality
            .AGGREGATION_TEMPORALITY_CUMULATIVE,
        dataPoints: metric.points.map(_toNumberDataPoint).toList(),
      );
      break;
    case otel_sdk.MetricType.gauge:
      metricProto.gauge = otlp_metrics.Gauge(
        dataPoints: metric.points.map(_toNumberDataPoint).toList(),
      );
      break;
    case otel_sdk.MetricType.histogram:
      metricProto.histogram = otlp_metrics.Histogram(
        aggregationTemporality: otlp_metrics.AggregationTemporality
            .AGGREGATION_TEMPORALITY_CUMULATIVE,
        dataPoints: metric.points.map(_toHistogramPoint).toList(),
      );
      break;
  }

  return metricProto;
}

otlp_metrics.NumberDataPoint _toNumberDataPoint(otel_sdk.MetricPoint point) {
  final value = point.value;
  final dataPoint = otlp_metrics.NumberDataPoint(
    attributes: _toKeyValues(point.attributes),
    startTimeUnixNano: _toUnixNanos(point.startTime),
    timeUnixNano: _toUnixNanos(point.endTime),
  );

  if (value is otel_sdk.SumMetricValue) {
    dataPoint.asDouble = value.sum;
  } else if (value is otel_sdk.GaugeMetricValue) {
    dataPoint.asDouble = value.value;
  } else {
    throw ArgumentError('Unsupported metric value: $value');
  }

  return dataPoint;
}

otlp_metrics.HistogramDataPoint _toHistogramPoint(
  otel_sdk.MetricPoint point,
) {
  final value = point.value;
  if (value is! otel_sdk.HistogramMetricValue) {
    throw ArgumentError('Metric point does not contain histogram data.');
  }
  return otlp_metrics.HistogramDataPoint(
    attributes: _toKeyValues(point.attributes),
    startTimeUnixNano: _toUnixNanos(point.startTime),
    timeUnixNano: _toUnixNanos(point.endTime),
    count: fixnum.Int64(value.count),
    sum: value.sum,
    bucketCounts:
        value.bucketCounts.map((bucket) => fixnum.Int64(bucket)).toList(),
    explicitBounds: value.explicitBounds,
  );
}

otlp_logs.LogRecord _toProtoLogRecord(otel_sdk.LogRecord record) {
  final data = record.data;
  final spanContext = record.spanContext;
  final severityNumber = otlp_logs.SeverityNumber.valueOf(data.severity.number) ??
      otlp_logs.SeverityNumber.SEVERITY_NUMBER_UNSPECIFIED;

  final logRecord = otlp_logs.LogRecord(
    timeUnixNano: _toUnixNanos(data.timestamp),
    observedTimeUnixNano: _toUnixNanos(data.observedTimestamp),
    severityNumber: severityNumber,
    severityText: data.severityText ?? data.severity.name.toUpperCase(),
    body: otlp_common.AnyValue(stringValue: data.body),
    attributes: _toKeyValues(data.attributes.toMap()),
    droppedAttributesCount: 0,
  );

  if (spanContext != null && spanContext.isValid) {
    logRecord.traceId = _hexToBytes(spanContext.traceId.value);
    logRecord.spanId = _hexToBytes(spanContext.spanId.value);
    logRecord.flags = spanContext.traceFlags.value;
  }

  return logRecord;
}

otlp_resource.Resource _toResource(otel_sdk.Resource resource) =>
    otlp_resource.Resource(
      attributes: _toKeyValues(resource.toMap()),
    );

otlp_common.InstrumentationScope _toInstrumentationScope(
        InstrumentationScope scope) =>
    otlp_common.InstrumentationScope(
      name: scope.name,
      version: scope.version ?? '',
    );

List<otlp_common.KeyValue> _toKeyValues(
    Map<String, AttributeValue> attributes) {
  return attributes.entries
      .map((entry) => otlp_common.KeyValue(
            key: entry.key,
            value: _toAnyValue(entry.value),
          ))
      .toList();
}

otlp_common.AnyValue _toAnyValue(AttributeValue value) {
  if (value is String) {
    return otlp_common.AnyValue(stringValue: value);
  }
  if (value is bool) {
    return otlp_common.AnyValue(boolValue: value);
  }
  if (value is int) {
    return otlp_common.AnyValue(intValue: fixnum.Int64(value));
  }
  if (value is double) {
    return otlp_common.AnyValue(doubleValue: value);
  }
  if (value is Iterable) {
    return otlp_common.AnyValue(
      arrayValue: otlp_common.ArrayValue(
        values: value.map((entry) => _toAnyValue(entry as AttributeValue)).toList(),
      ),
    );
  }
  throw ArgumentError('Unsupported attribute value type: ${value.runtimeType}');
}

otlp_trace.Span_SpanKind _mapSpanKind(SpanKind kind) {
  switch (kind) {
    case SpanKind.internal:
      return otlp_trace.Span_SpanKind.SPAN_KIND_INTERNAL;
    case SpanKind.server:
      return otlp_trace.Span_SpanKind.SPAN_KIND_SERVER;
    case SpanKind.client:
      return otlp_trace.Span_SpanKind.SPAN_KIND_CLIENT;
    case SpanKind.producer:
      return otlp_trace.Span_SpanKind.SPAN_KIND_PRODUCER;
    case SpanKind.consumer:
      return otlp_trace.Span_SpanKind.SPAN_KIND_CONSUMER;
  }
}

otlp_trace.Status_StatusCode _mapStatusCode(StatusCode status) {
  switch (status) {
    case StatusCode.unset:
      return otlp_trace.Status_StatusCode.STATUS_CODE_UNSET;
    case StatusCode.ok:
      return otlp_trace.Status_StatusCode.STATUS_CODE_OK;
    case StatusCode.error:
      return otlp_trace.Status_StatusCode.STATUS_CODE_ERROR;
  }
}

fixnum.Int64 _toUnixNanos(DateTime timestamp) {
  final micros = timestamp.toUtc().microsecondsSinceEpoch;
  return fixnum.Int64(micros) * fixnum.Int64(1000);
}

Uint8List _hexToBytes(String hex) {
  final length = hex.length;
  final bytes = Uint8List(length ~/ 2);
  for (var i = 0; i < length; i += 2) {
    final byte = int.parse(hex.substring(i, i + 2), radix: 16);
    bytes[i ~/ 2] = byte;
  }
  return bytes;
}
