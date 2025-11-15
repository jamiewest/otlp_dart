import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:shared/shared.dart';

import 'metric_data.dart';
import 'metric_storage.dart';

class SdkMeter implements Meter {
  SdkMeter(this._registerStorage, this._scope, this._histogramBoundaries);

  final void Function(MetricStorage storage, InstrumentationScope scope)
      _registerStorage;
  final InstrumentationScope _scope;
  final List<double> _histogramBoundaries;

  @override
  Counter createCounter(String name, {String? description, String? unit}) {
    final descriptor = MetricDescriptor(
      name: name,
      description: description,
      unit: unit,
      type: MetricType.sum,
    );
    final storage = SyncMetricStorage(
      descriptor: descriptor,
      createAggregator: () => SumAggregator(),
      monotonic: true,
    );
    _registerStorage(storage, _scope);
    return _CounterInstrument(storage);
  }

  @override
  Histogram createHistogram(String name,
      {String? description, String? unit}) {
    final descriptor = MetricDescriptor(
      name: name,
      description: description,
      unit: unit,
      type: MetricType.histogram,
    );
    final storage = SyncMetricStorage(
      descriptor: descriptor,
      createAggregator: () => HistogramAggregator(_histogramBoundaries),
      monotonic: true,
    );
    _registerStorage(storage, _scope);
    return _HistogramInstrument(storage);
  }

  @override
  ObservableGauge createObservableGauge(String name,
      {String? description, String? unit, ObservableCallback? callback}) {
    final descriptor = MetricDescriptor(
      name: name,
      description: description,
      unit: unit,
      type: MetricType.gauge,
    );
    final storage = ObservableGaugeStorage(descriptor: descriptor);
    _registerStorage(storage, _scope);
    final gauge = _ObservableGaugeInstrument(storage);
    if (callback != null) {
      gauge.observe(callback);
    }
    return gauge;
  }

  @override
  UpDownCounter createUpDownCounter(String name,
      {String? description, String? unit}) {
    final descriptor = MetricDescriptor(
      name: name,
      description: description,
      unit: unit,
      type: MetricType.upDownSum,
    );
    final storage = SyncMetricStorage(
      descriptor: descriptor,
      createAggregator: () => SumAggregator(),
      monotonic: false,
    );
    _registerStorage(storage, _scope);
    return _UpDownCounterInstrument(storage);
  }
}

class _CounterInstrument implements Counter {
  _CounterInstrument(this._storage);

  final SyncMetricStorage _storage;

  @override
  void add(num value, {Map<String, AttributeValue> attributes = const {}}) {
    if (value <= 0) {
      return;
    }
    _storage.record(value, attributes);
  }
}

class _UpDownCounterInstrument implements UpDownCounter {
  _UpDownCounterInstrument(this._storage);

  final SyncMetricStorage _storage;

  @override
  void add(num value, {Map<String, AttributeValue> attributes = const {}}) {
    _storage.record(value, attributes);
  }
}

class _HistogramInstrument implements Histogram {
  _HistogramInstrument(this._storage);

  final SyncMetricStorage _storage;

  @override
  void record(num value, {Map<String, AttributeValue> attributes = const {}}) {
    _storage.record(value, attributes);
  }
}

class _ObservableGaugeInstrument implements ObservableGauge {
  _ObservableGaugeInstrument(this._storage);

  final ObservableGaugeStorage _storage;

  @override
  void observe(ObservableCallback callback) {
    _storage.addCallback(callback);
  }

  @override
  void unobserve(ObservableCallback callback) {
    _storage.removeCallback(callback);
  }
}
