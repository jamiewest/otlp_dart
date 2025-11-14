import '../trace/export_result.dart';
import 'log_record.dart';

abstract class LogRecordExporter {
  const LogRecordExporter();

  Future<ExportResult> export(List<LogRecord> records);

  Future<void> forceFlush() async {}

  Future<void> shutdown() async {}
}

class NoopLogRecordExporter extends LogRecordExporter {
  const NoopLogRecordExporter();

  @override
  Future<ExportResult> export(List<LogRecord> records) async =>
      ExportResult.success;
}
