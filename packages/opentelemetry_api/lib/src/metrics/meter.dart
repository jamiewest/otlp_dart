import 'instruments.dart';
import 'measurement.dart';

abstract class Meter {
  Counter createCounter(String name,
      {String? description, String? unit});

  UpDownCounter createUpDownCounter(String name,
      {String? description, String? unit});

  Histogram createHistogram(String name,
      {String? description, String? unit});

  ObservableGauge createObservableGauge(String name,
      {String? description,
      String? unit,
      ObservableCallback? callback});
}
