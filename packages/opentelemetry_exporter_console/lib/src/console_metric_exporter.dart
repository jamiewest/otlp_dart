import 'dart:convert';

import 'package:opentelemetry_sdk/opentelemetry_sdk.dart';

import 'io/console_writer.dart';

class ConsoleMetricExporter extends MetricExporter {
  ConsoleMetricExporter({this.prettyPrint = true});

  final bool prettyPrint;

  JsonEncoder get _encoder =>
      prettyPrint ? const JsonEncoder.withIndent('  ') : const JsonEncoder();

  @override
  Future<ExportResult> export(List<MetricData> metrics) async {
    for (final metric in metrics) {
      final payload = _serializeMetric(metric);
      ConsoleWriterHolder.instance.write(_encoder.convert(payload));
    }
    return ExportResult.success;
  }
}

Map<String, Object?> _serializeMetric(MetricData metric) {
  return {
    'name': metric.descriptor.name,
    'description': metric.descriptor.description,
    'unit': metric.descriptor.unit,
    'type': metric.descriptor.type.name,
    'resource': metric.resource.toMap(),
    'instrumentationScope': {
      'name': metric.instrumentationScope.name,
      'version': metric.instrumentationScope.version,
      'schemaUrl': metric.instrumentationScope.schemaUrl,
    },
    'points': metric.points.map(_serializePoint).toList(),
  };
}

Map<String, Object?> _serializePoint(MetricPoint point) {
  Object? value;
  if (point.value is SumMetricValue) {
    final sum = point.value as SumMetricValue;
    value = {
      'type': 'sum',
      'sum': sum.sum,
      'isMonotonic': sum.isMonotonic,
    };
  } else if (point.value is GaugeMetricValue) {
    final gauge = point.value as GaugeMetricValue;
    value = {
      'type': 'gauge',
      'value': gauge.value,
    };
  } else if (point.value is HistogramMetricValue) {
    final histogram = point.value as HistogramMetricValue;
    value = {
      'type': 'histogram',
      'sum': histogram.sum,
      'count': histogram.count,
      'bucketCounts': histogram.bucketCounts,
      'explicitBounds': histogram.explicitBounds,
    };
  }

  return {
    'startTime': point.startTime.toIso8601String(),
    'endTime': point.endTime.toIso8601String(),
    'attributes': point.attributes,
    'value': value,
  };
}
