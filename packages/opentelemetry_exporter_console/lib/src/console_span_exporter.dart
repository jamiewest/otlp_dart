import 'dart:convert';

import 'package:opentelemetry_sdk/opentelemetry_sdk.dart';

import 'io/console_writer.dart';

class ConsoleSpanExporter extends SpanExporter {
  ConsoleSpanExporter({this.prettyPrint = true});

  final bool prettyPrint;
  JsonEncoder get _encoder =>
      prettyPrint ? const JsonEncoder.withIndent('  ') : const JsonEncoder();

  @override
  Future<ExportResult> export(List<SpanData> spans) async {
    for (final span in spans) {
      final payload = _serializeSpan(span);
      ConsoleWriterHolder.instance.write(_encoder.convert(payload));
    }
    return ExportResult.success;
  }
}

Map<String, Object?> _serializeSpan(SpanData span) {
  return {
    'traceId': span.context.traceId.value,
    'spanId': span.context.spanId.value,
    'parentSpanId': span.parentSpanContext?.spanId.value,
    'name': span.name,
    'kind': span.kind.name,
    'status': span.status.statusCode.name,
    'startTime': span.startTime.toIso8601String(),
    'endTime': span.endTime.toIso8601String(),
    'attributes': span.attributes.toMap(),
    'events': span.events
        .map((event) => {
              'name': event.name,
              'timestamp': event.timestamp.toIso8601String(),
              'attributes': event.attributes.toMap(),
            })
        .toList(),
    'links': span.links
        .map((link) => {
              'traceId': link.context.traceId.value,
              'spanId': link.context.spanId.value,
              'attributes': link.attributes.toMap(),
            })
        .toList(),
    'resource': span.resource.toMap(),
    'instrumentationScope': {
      'name': span.instrumentationScope.name,
      'version': span.instrumentationScope.version,
      'schemaUrl': span.instrumentationScope.schemaUrl,
    },
  };
}
