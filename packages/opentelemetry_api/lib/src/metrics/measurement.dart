import '../trace/attributes.dart';

typedef MeasurementCallback = Iterable<Measurement> Function();

typedef ObservableCallback = Iterable<Measurement> Function();

class Measurement {
  Measurement(this.value, {Map<String, AttributeValue> attributes = const {}})
      : attributes = Attributes(attributes);

  final double value;
  final Attributes attributes;
}
