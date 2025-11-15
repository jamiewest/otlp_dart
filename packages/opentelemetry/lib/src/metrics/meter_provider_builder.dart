import '../resource/resource.dart';
import 'metric_exporter.dart';
import 'metric_pipeline_config.dart';
import 'sdk_meter_provider.dart';

class SdkMeterProviderBuilder {
  final List<MetricPipelineConfig> _pipelines = [];
  Resource _resource = Resource.defaultResource();
  List<double>? _histogramBoundaries;

  SdkMeterProviderBuilder addMetricExporter(MetricExporter exporter,
      {Duration? exportInterval}) {
    _pipelines.add(
        MetricPipelineConfig(exporter: exporter, exportInterval: exportInterval));
    return this;
  }

  SdkMeterProviderBuilder setResource(Resource resource) {
    _resource = resource;
    return this;
  }

  SdkMeterProviderBuilder setHistogramBoundaries(List<double> boundaries) {
    _histogramBoundaries = List<double>.from(boundaries);
    return this;
  }

  SdkMeterProvider build() {
    if (_pipelines.isEmpty) {
      _pipelines.add(MetricPipelineConfig(
          exporter: const NoopMetricExporter(), exportInterval: null));
    }
    return SdkMeterProvider(
      resource: _resource,
      pipelineConfigs: List.unmodifiable(_pipelines),
      histogramBoundaries: _histogramBoundaries,
    );
  }
}
