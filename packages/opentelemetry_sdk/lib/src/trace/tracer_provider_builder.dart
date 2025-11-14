import '../resource/resource.dart';
import 'id_generator.dart';
import 'sampler.dart';
import 'sdk_tracer.dart';
import 'span_exporter.dart';
import 'span_processor.dart';

class SdkTracerProviderBuilder {
  final List<SpanProcessor> _processors = [];
  Sampler _sampler = const AlwaysOnSampler();
  IdGenerator _idGenerator = const RandomIdGenerator();
  Resource _resource = Resource.defaultResource();

  SdkTracerProviderBuilder addSpanProcessor(SpanProcessor processor) {
    _processors.add(processor);
    return this;
  }

  SdkTracerProviderBuilder setSampler(Sampler sampler) {
    _sampler = sampler;
    return this;
  }

  SdkTracerProviderBuilder setIdGenerator(IdGenerator idGenerator) {
    _idGenerator = idGenerator;
    return this;
  }

  SdkTracerProviderBuilder setResource(Resource resource) {
    _resource = resource;
    return this;
  }

  SdkTracerProvider build() {
    final processor = _processors.isEmpty
        ? SimpleSpanProcessor(const NoopSpanExporter())
        : _processors.length == 1
            ? _processors.first
            : MultiSpanProcessor(List.unmodifiable(_processors));
    return SdkTracerProvider(
      resource: _resource,
      sampler: _sampler,
      idGenerator: _idGenerator,
      spanProcessor: processor,
    );
  }
}
