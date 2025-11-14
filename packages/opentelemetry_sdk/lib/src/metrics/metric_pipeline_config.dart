import 'metric_exporter.dart';

class MetricPipelineConfig {
  MetricPipelineConfig({required this.exporter, this.exportInterval});

  final MetricExporter exporter;
  final Duration? exportInterval;
}
