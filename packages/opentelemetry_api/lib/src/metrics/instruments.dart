import '../trace/attributes.dart';
import 'measurement.dart';

abstract class Counter {
  void add(num value, {Map<String, AttributeValue> attributes = const {}});
}

abstract class UpDownCounter {
  void add(num value, {Map<String, AttributeValue> attributes = const {}});
}

abstract class Histogram {
  void record(num value, {Map<String, AttributeValue> attributes = const {}});
}

abstract class ObservableGauge {
  void observe(ObservableCallback callback);

  void unobserve(ObservableCallback callback);
}
