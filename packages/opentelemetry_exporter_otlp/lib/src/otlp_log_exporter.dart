import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:opentelemetry_sdk/opentelemetry_sdk.dart';
import 'package:opentelemetry_shared/opentelemetry_shared.dart';

import 'otlp_encoding.dart';
import 'otlp_http_sender.dart';
import 'otlp_options.dart';

class OtlpLogExporter extends LogRecordExporter {
  OtlpLogExporter({
    OtlpExporterOptions? options,
    http.Client? httpClient,
    RetryPolicy? retryPolicy,
  }) : _sender = OtlpHttpSender(
          options: options ?? OtlpExporterOptions.forSignal(OtlpSignal.logs),
          client: httpClient,
          retryPolicy: retryPolicy,
        );

  final OtlpHttpSender _sender;
  bool _isShutdown = false;

  @override
  Future<ExportResult> export(List<LogRecord> records) async {
    if (_isShutdown || records.isEmpty) {
      return ExportResult.success;
    }
    final payload = jsonEncode(
        {'resourceLogs': _buildResourceLogs(records)});
    return _sender.send(payload);
  }

  @override
  Future<void> shutdown() async {
    if (_isShutdown) {
      return;
    }
    _isShutdown = true;
    await _sender.shutdown();
  }
}

List<Map<String, Object?>> _buildResourceLogs(List<LogRecord> records) {
  final Map<Resource, Map<InstrumentationScope, List<LogRecord>>> groups = {};
  for (final record in records) {
    final scopeGroup = groups.putIfAbsent(
        record.resource, () => <InstrumentationScope, List<LogRecord>>{});
    final bucket = scopeGroup.putIfAbsent(
        record.instrumentationScope, () => <LogRecord>[]);
    bucket.add(record);
  }

  return groups.entries.map((resourceEntry) {
    final resource = resourceEntry.key;
    final scopeLogs = resourceEntry.value.entries.map((scopeEntry) {
      return {
        'scope': encodeInstrumentationScope(scopeEntry.key),
        'logRecords': scopeEntry.value.map(_encodeLogRecord).toList(),
      };
    }).toList();

    return {
      'resource': {'attributes': encodeAttributes(resource.toMap())},
      'scopeLogs': scopeLogs,
    };
  }).toList();
}

Map<String, Object?> _encodeLogRecord(LogRecord record) {
  final spanContext = record.spanContext;
  return {
    'timeUnixNano': toUnixNanos(record.data.timestamp),
    'observedTimeUnixNano': toUnixNanos(record.data.observedTimestamp),
    'severityNumber': record.data.severity.number,
    'severityText':
        record.data.severityText ?? record.data.severity.name.toUpperCase(),
    'body': {'stringValue': record.data.body},
    'attributes': encodeAttributes(record.data.attributes.toMap()),
    if (spanContext != null && spanContext.isValid)
      'traceId': hexToBase64(spanContext.traceId.value),
    if (spanContext != null && spanContext.isValid)
      'spanId': hexToBase64(spanContext.spanId.value),
  };
}
