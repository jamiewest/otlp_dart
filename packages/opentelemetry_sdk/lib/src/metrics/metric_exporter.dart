import '../trace/export_result.dart';
import 'metric_data.dart';

abstract class MetricExporter {
  const MetricExporter();

  Future<ExportResult> export(List<MetricData> metrics);

  Future<void> forceFlush() async {}

  Future<void> shutdown() async {}
}

class NoopMetricExporter extends MetricExporter {
  const NoopMetricExporter();

  @override
  Future<ExportResult> export(List<MetricData> metrics) async =>
      ExportResult.success;
}
