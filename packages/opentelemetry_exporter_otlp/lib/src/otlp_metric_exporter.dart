import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:opentelemetry_sdk/opentelemetry_sdk.dart';
import 'package:opentelemetry_shared/opentelemetry_shared.dart';

import 'otlp_encoding.dart';
import 'otlp_http_sender.dart';
import 'otlp_options.dart';

class OtlpMetricExporter extends MetricExporter {
  OtlpMetricExporter({
    OtlpExporterOptions? options,
    http.Client? httpClient,
    RetryPolicy? retryPolicy,
  }) : _sender = OtlpHttpSender(
          options: options ?? OtlpExporterOptions.forSignal(OtlpSignal.metrics),
          client: httpClient,
          retryPolicy: retryPolicy,
        );

  final OtlpHttpSender _sender;
  bool _isShutdown = false;

  @override
  Future<ExportResult> export(List<MetricData> metrics) async {
    if (_isShutdown || metrics.isEmpty) {
      return ExportResult.success;
    }
    final payload = jsonEncode(
        {'resourceMetrics': _buildResourceMetrics(metrics)});
    return _sender.send(payload);
  }

  @override
  Future<void> shutdown() async {
    if (_isShutdown) {
      return;
    }
    _isShutdown = true;
    await _sender.shutdown();
  }
}

List<Map<String, Object?>> _buildResourceMetrics(List<MetricData> metrics) {
  final Map<Resource, Map<InstrumentationScope, List<MetricData>>> groups = {};
  for (final metric in metrics) {
    final scopeGroup = groups.putIfAbsent(
        metric.resource, () => <InstrumentationScope, List<MetricData>>{});
    final bucket = scopeGroup.putIfAbsent(
        metric.instrumentationScope, () => <MetricData>[]);
    bucket.add(metric);
  }

  return groups.entries.map((resourceEntry) {
    final resource = resourceEntry.key;
    final scopeMetrics = resourceEntry.value.entries.map((scopeEntry) {
      return {
        'scope': encodeInstrumentationScope(scopeEntry.key),
        'metrics': scopeEntry.value.map(_encodeMetric).toList(),
      };
    }).toList();

    return {
      'resource': {'attributes': encodeAttributes(resource.toMap())},
      'scopeMetrics': scopeMetrics,
    };
  }).toList();
}

Map<String, Object?> _encodeMetric(MetricData metric) {
  final descriptor = metric.descriptor;
  final base = {
    'name': descriptor.name,
    'description': descriptor.description ?? '',
    'unit': descriptor.unit ?? '',
  };

  switch (descriptor.type) {
    case MetricType.sum:
    case MetricType.upDownSum:
      final isMonotonic = descriptor.type == MetricType.sum;
      return {
        ...base,
        'sum': {
          'aggregationTemporality': 2,
          'isMonotonic': isMonotonic,
          'dataPoints': metric.points
              .map((point) => _encodeNumberPoint(point))
              .toList(),
        },
      };
    case MetricType.gauge:
      return {
        ...base,
        'gauge': {
          'dataPoints':
              metric.points.map((point) => _encodeNumberPoint(point)).toList(),
        },
      };
    case MetricType.histogram:
      return {
        ...base,
        'histogram': {
          'aggregationTemporality': 2,
          'dataPoints':
              metric.points.map((point) => _encodeHistogramPoint(point)).toList(),
        },
      };
  }
}

Map<String, Object?> _encodeNumberPoint(MetricPoint point) {
  double value;
  if (point.value is SumMetricValue) {
    value = (point.value as SumMetricValue).sum;
  } else if (point.value is GaugeMetricValue) {
    value = (point.value as GaugeMetricValue).value;
  } else {
    throw ArgumentError('Expected numeric point, received ${point.value}');
  }

  return {
    'attributes': encodeAttributes(point.attributes),
    'startTimeUnixNano': toUnixNanos(point.startTime),
    'timeUnixNano': toUnixNanos(point.endTime),
    'asDouble': value,
  };
}

Map<String, Object?> _encodeHistogramPoint(MetricPoint point) {
  final histogram = point.value as HistogramMetricValue;
  return {
    'attributes': encodeAttributes(point.attributes),
    'startTimeUnixNano': toUnixNanos(point.startTime),
    'timeUnixNano': toUnixNanos(point.endTime),
    'count': histogram.count,
    'sum': histogram.sum,
    'bucketCounts': histogram.bucketCounts,
    'explicitBounds': histogram.explicitBounds,
  };
}
