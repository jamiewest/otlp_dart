import '../../context/context.dart';
import 'text_map_propagator.dart';

class CompositeTextMapPropagator extends TextMapPropagator {
  const CompositeTextMapPropagator(this._propagators);

  final List<TextMapPropagator> _propagators;

  @override
  Iterable<String> get fields =>
      _propagators.expand((propagator) => propagator.fields).toSet();

  @override
  Context extract<T>(Context context, T carrier, TextMapGetter<T> getter) {
    var result = context;
    for (final propagator in _propagators) {
      result = propagator.extract(result, carrier, getter);
    }
    return result;
  }

  @override
  void inject<T>(Context context, T carrier, TextMapSetter<T> setter) {
    for (final propagator in _propagators) {
      propagator.inject(context, carrier, setter);
    }
  }
}
