import '../trace/attributes.dart';
import 'instruments.dart';
import 'measurement.dart';
import 'meter.dart';

abstract class MeterProvider {
  Meter getMeter(String name, {String? version, String? schemaUrl});

  Future<void> forceFlush() async {}

  Future<void> shutdown() async {}
}

class NoopMeterProvider implements MeterProvider {
  const NoopMeterProvider();

  static const NoopMeterProvider instance = NoopMeterProvider();

  @override
  Meter getMeter(String name, {String? version, String? schemaUrl}) =>
      _NoopMeter();

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {}
}

class _NoopMeter implements Meter {
  @override
  Counter createCounter(String name, {String? description, String? unit}) =>
      _NoopCounter();

  @override
  Histogram createHistogram(String name,
          {String? description, String? unit}) =>
      _NoopHistogram();

  @override
  ObservableGauge createObservableGauge(String name,
          {String? description, String? unit, ObservableCallback? callback}) =>
      _NoopObservableGauge();

  @override
  UpDownCounter createUpDownCounter(String name,
          {String? description, String? unit}) =>
      _NoopUpDownCounter();
}

class _NoopCounter implements Counter {
  @override
  void add(num value, {Map<String, AttributeValue> attributes = const {}}) {}
}

class _NoopUpDownCounter implements UpDownCounter {
  @override
  void add(num value, {Map<String, AttributeValue> attributes = const {}}) {}
}

class _NoopHistogram implements Histogram {
  @override
  void record(num value, {Map<String, AttributeValue> attributes = const {}}) {}
}

class _NoopObservableGauge implements ObservableGauge {
  @override
  void observe(ObservableCallback callback) {}

  @override
  void unobserve(ObservableCallback callback) {}
}
