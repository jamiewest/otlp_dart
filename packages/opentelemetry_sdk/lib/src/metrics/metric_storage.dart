import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:opentelemetry_shared/opentelemetry_shared.dart';

import '../resource/resource.dart';
import 'metric_data.dart';

abstract class MetricStorage {
  MetricDescriptor get descriptor;

  MetricData? collect(
      Resource Function() resourceProvider, InstrumentationScope scope);
}

typedef MetricPointsBuilder = List<MetricPoint> Function(DateTime timestamp);

class SyncMetricStorage extends MetricStorage {
  SyncMetricStorage({
    required MetricDescriptor descriptor,
    required this.createAggregator,
    bool monotonic = false,
  })  : _descriptor = descriptor,
        _monotonic = monotonic,
        _startTime = DateTime.now().toUtc();

  final MetricDescriptor _descriptor;
  final bool _monotonic;
  final Aggregator Function() createAggregator;
  final DateTime _startTime;
  final Map<String, Aggregator> _points = {};

  @override
  MetricDescriptor get descriptor => _descriptor;

  void record(num value, Map<String, AttributeValue> attributes) {
    final normalized = Map<String, AttributeValue>.from(attributes);
    final key = _serialize(normalized);
    final aggregator = _points.putIfAbsent(key, () {
      final agg = createAggregator();
      agg.attributes = normalized;
      return agg;
    });
    aggregator.record(value.toDouble());
  }

  @override
  MetricData? collect(
      Resource Function() resourceProvider, InstrumentationScope scope) {
    if (_points.isEmpty) {
      return null;
    }
    final timestamp = DateTime.now().toUtc();
    final points = <MetricPoint>[];
    for (final aggregator in _points.values) {
      final value = aggregator.toMetricValue(monotonic: _monotonic);
      if (value == null) {
        continue;
      }
      points.add(MetricPoint(
        startTime: _startTime,
        endTime: timestamp,
        attributes: aggregator.attributes,
        value: value,
      ));
    }
    if (points.isEmpty) {
      return null;
    }
    return MetricData(
      descriptor: descriptor,
      resource: resourceProvider(),
      instrumentationScope: scope,
      points: points,
    );
  }

  String _serialize(Map<String, AttributeValue> attributes) {
    final entries = attributes.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((e) => '${e.key}=${e.value}').join('|');
  }
}

abstract class Aggregator {
  late Map<String, AttributeValue> attributes;

  void record(double value);

  MetricValue? toMetricValue({required bool monotonic});
}

class SumAggregator extends Aggregator {
  double _sum = 0;

  @override
  void record(double value) {
    _sum += value;
  }

  @override
  MetricValue toMetricValue({required bool monotonic}) =>
      SumMetricValue(_sum, isMonotonic: monotonic);
}

class GaugeAggregator extends Aggregator {
  double? _value;

  @override
  void record(double value) {
    _value = value;
  }

  @override
  MetricValue? toMetricValue({required bool monotonic}) {
    final current = _value;
    if (current == null) {
      return null;
    }
    return GaugeMetricValue(current);
  }
}

class HistogramAggregator extends Aggregator {
  HistogramAggregator(this._boundaries)
      : _bucketCounts = List<int>.filled(_boundaries.length + 1, 0),
        _sum = 0,
        _count = 0;

  final List<double> _boundaries;
  final List<int> _bucketCounts;
  double _sum;
  int _count;

  @override
  void record(double value) {
    _sum += value;
    _count++;
    var placed = false;
    for (var i = 0; i < _boundaries.length; i++) {
      if (value <= _boundaries[i]) {
        _bucketCounts[i]++;
        placed = true;
        break;
      }
    }
    if (!placed) {
      _bucketCounts[_bucketCounts.length - 1]++;
    }
  }

  @override
  MetricValue toMetricValue({required bool monotonic}) => HistogramMetricValue(
        sum: _sum,
        count: _count,
        bucketCounts: List<int>.from(_bucketCounts),
        explicitBounds: List<double>.from(_boundaries),
      );
}

class ObservableGaugeStorage extends MetricStorage {
  ObservableGaugeStorage({required MetricDescriptor descriptor})
      : _descriptor = descriptor;

  final MetricDescriptor _descriptor;
  final Set<ObservableCallback> _callbacks = <ObservableCallback>{};

  void addCallback(ObservableCallback callback) => _callbacks.add(callback);

  void removeCallback(ObservableCallback callback) => _callbacks.remove(callback);

  @override
  MetricDescriptor get descriptor => _descriptor;

  @override
  MetricData? collect(
      Resource Function() resourceProvider, InstrumentationScope scope) {
    if (_callbacks.isEmpty) {
      return null;
    }
    final timestamp = DateTime.now().toUtc();
    final points = <MetricPoint>[];
    for (final callback in _callbacks) {
      Iterable<Measurement> measurements;
      try {
        measurements = callback();
      } catch (_) {
        continue;
      }
      for (final measurement in measurements) {
        points.add(MetricPoint(
          startTime: timestamp,
          endTime: timestamp,
          attributes: measurement.attributes.toMap(),
          value: GaugeMetricValue(measurement.value),
        ));
      }
    }
    if (points.isEmpty) {
      return null;
    }
    return MetricData(
      descriptor: descriptor,
      resource: resourceProvider(),
      instrumentationScope: scope,
      points: points,
    );
  }
}
