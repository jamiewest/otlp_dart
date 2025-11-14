import 'dart:convert';

import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:opentelemetry_sdk/opentelemetry_sdk.dart';

import 'io/console_writer.dart';

class ConsoleLogExporter extends LogRecordExporter {
  ConsoleLogExporter({this.prettyPrint = true});

  final bool prettyPrint;

  JsonEncoder get _encoder =>
      prettyPrint ? const JsonEncoder.withIndent('  ') : const JsonEncoder();

  @override
  Future<ExportResult> export(List<LogRecord> records) async {
    for (final record in records) {
      final payload = _serializeLog(record);
      ConsoleWriterHolder.instance.write(_encoder.convert(payload));
    }
    return ExportResult.success;
  }
}

Map<String, Object?> _serializeLog(LogRecord record) {
  final spanContext = record.spanContext;
  return {
    'timestamp': record.data.timestamp.toIso8601String(),
    'observedTimestamp': record.data.observedTimestamp.toIso8601String(),
    'severity': record.data.severity.name,
    'severityNumber': record.data.severity.number,
    if (record.data.severityText != null)
      'severityText': record.data.severityText,
    'body': record.data.body,
    'attributes': record.data.attributes.toMap(),
    'resource': record.resource.toMap(),
    'instrumentationScope': {
      'name': record.instrumentationScope.name,
      'version': record.instrumentationScope.version,
      'schemaUrl': record.instrumentationScope.schemaUrl,
    },
    if (spanContext != null && spanContext.isValid)
      'spanContext': {
        'traceId': spanContext.traceId.value,
        'spanId': spanContext.spanId.value,
        'traceFlags': spanContext.traceFlags.value,
      },
  };
}
