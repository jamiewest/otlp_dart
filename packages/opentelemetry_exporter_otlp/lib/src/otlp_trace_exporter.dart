import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:opentelemetry_sdk/opentelemetry_sdk.dart';
import 'package:opentelemetry_shared/opentelemetry_shared.dart';

import 'otlp_encoding.dart';
import 'otlp_http_sender.dart';
import 'otlp_options.dart';

class OtlpTraceExporter extends SpanExporter {
  OtlpTraceExporter({
    OtlpExporterOptions? options,
    http.Client? httpClient,
    RetryPolicy? retryPolicy,
  }) : _sender = OtlpHttpSender(
          options: options ?? OtlpExporterOptions.forSignal(OtlpSignal.traces),
          client: httpClient,
          retryPolicy: retryPolicy,
        );

  final OtlpHttpSender _sender;
  bool _isShutdown = false;

  @override
  Future<ExportResult> export(List<SpanData> spans) async {
    if (_isShutdown || spans.isEmpty) {
      return ExportResult.success;
    }
    final payload = jsonEncode({'resourceSpans': _buildResourceSpans(spans)});
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

List<Map<String, Object?>> _buildResourceSpans(List<SpanData> spans) {
  final Map<Resource, Map<InstrumentationScope, List<SpanData>>> groups = {};
  for (final span in spans) {
    final scopeGroup =
        groups.putIfAbsent(span.resource, () => <InstrumentationScope, List<SpanData>>{});
    final bucket =
        scopeGroup.putIfAbsent(span.instrumentationScope, () => <SpanData>[]);
    bucket.add(span);
  }

  return groups.entries.map((resourceEntry) {
    final resource = resourceEntry.key;
    final scopeSpans = resourceEntry.value.entries.map((scopeEntry) {
      return {
        'scope': encodeInstrumentationScope(scopeEntry.key),
        'spans': scopeEntry.value.map(_encodeSpan).toList(),
      };
    }).toList();

    return {
      'resource': {'attributes': encodeAttributes(resource.toMap())},
      'scopeSpans': scopeSpans,
    };
  }).toList();
}

Map<String, Object?> _encodeSpan(SpanData span) {
  return {
    'traceId': hexToBase64(span.context.traceId.value),
    'spanId': hexToBase64(span.context.spanId.value),
    if (span.parentSpanContext != null)
      'parentSpanId': hexToBase64(span.parentSpanContext!.spanId.value),
    'name': span.name,
    'kind': _mapSpanKind(span.kind),
    'startTimeUnixNano': toUnixNanos(span.startTime),
    'endTimeUnixNano': toUnixNanos(span.endTime),
    'attributes': encodeAttributes(span.attributes.toMap()),
    'events': span.events.map(_encodeEvent).toList(),
    'links': span.links.map(_encodeLink).toList(),
    'status': _encodeStatus(span.status),
    'droppedAttributesCount': 0,
    'droppedEventsCount': 0,
    'droppedLinksCount': 0,
    if (!span.context.traceState.isEmpty)
      'traceState': span.context.traceState.entries
          .map((e) => '${e.key}=${e.value}')
          .join(','),
  };
}

Map<String, Object?> _encodeEvent(SpanEvent event) => {
      'name': event.name,
      'timeUnixNano': toUnixNanos(event.timestamp),
      'attributes': encodeAttributes(event.attributes.toMap()),
      'droppedAttributesCount': 0,
    };

Map<String, Object?> _encodeLink(Link link) => {
      'traceId': hexToBase64(link.context.traceId.value),
      'spanId': hexToBase64(link.context.spanId.value),
      if (!link.context.traceState.isEmpty)
        'traceState': link.context.traceState.entries
            .map((e) => '${e.key}=${e.value}')
            .join(','),
      'attributes': encodeAttributes(link.attributes.toMap()),
      'droppedAttributesCount': 0,
    };

Map<String, Object?> _encodeStatus(Status status) => {
      'code': _mapStatusCode(status.statusCode),
      if (status.description != null) 'message': status.description,
    };

int _mapSpanKind(SpanKind kind) {
  switch (kind) {
    case SpanKind.internal:
      return 1;
    case SpanKind.server:
      return 2;
    case SpanKind.client:
      return 3;
    case SpanKind.producer:
      return 4;
    case SpanKind.consumer:
      return 5;
  }
}

int _mapStatusCode(StatusCode status) {
  switch (status) {
    case StatusCode.unset:
      return 0;
    case StatusCode.ok:
      return 1;
    case StatusCode.error:
      return 2;
  }
}
