import 'export_result.dart';
import 'span_data.dart';

abstract class SpanExporter {
  const SpanExporter();

  Future<ExportResult> export(List<SpanData> spans);

  Future<void> forceFlush() async {}

  Future<void> shutdown() async {}
}

class NoopSpanExporter extends SpanExporter {
  const NoopSpanExporter();

  @override
  Future<ExportResult> export(List<SpanData> spans) async =>
      ExportResult.success;
}
