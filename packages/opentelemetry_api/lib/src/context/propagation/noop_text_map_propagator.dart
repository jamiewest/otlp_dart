import '../../context/context.dart';
import 'text_map_propagator.dart';

class NoopTextMapPropagator extends TextMapPropagator {
  const NoopTextMapPropagator();

  @override
  Iterable<String> get fields => const [];

  @override
  Context extract<T>(Context context, T carrier, TextMapGetter<T> getter) =>
      context;

  @override
  void inject<T>(Context context, T carrier, TextMapSetter<T> setter) {}
}
