import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:opentelemetry_shared/opentelemetry_shared.dart';

import '../resource/resource.dart';

enum MetricType { sum, upDownSum, histogram, gauge }

class MetricDescriptor {
  const MetricDescriptor({
    required this.name,
    required this.type,
    this.description,
    this.unit,
  });

  final String name;
  final MetricType type;
  final String? description;
  final String? unit;
}

abstract class MetricValue {}

class SumMetricValue extends MetricValue {
  SumMetricValue(this.sum, {required this.isMonotonic});

  final double sum;
  final bool isMonotonic;
}

class GaugeMetricValue extends MetricValue {
  GaugeMetricValue(this.value);

  final double value;
}

class HistogramMetricValue extends MetricValue {
  HistogramMetricValue({
    required this.sum,
    required this.count,
    required this.bucketCounts,
    required this.explicitBounds,
  });

  final double sum;
  final int count;
  final List<int> bucketCounts;
  final List<double> explicitBounds;
}

class MetricPoint {
  MetricPoint({
    required this.startTime,
    required this.endTime,
    required this.attributes,
    required this.value,
  });

  final DateTime startTime;
  final DateTime endTime;
  final Map<String, AttributeValue> attributes;
  final MetricValue value;
}

class MetricData {
  MetricData({
    required this.descriptor,
    required this.resource,
    required this.instrumentationScope,
    required this.points,
  });

  final MetricDescriptor descriptor;
  final Resource resource;
  final InstrumentationScope instrumentationScope;
  final List<MetricPoint> points;

  bool get isEmpty => points.isEmpty;
}
