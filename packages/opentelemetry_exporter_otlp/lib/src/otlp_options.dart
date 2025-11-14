import 'package:opentelemetry_shared/opentelemetry_shared.dart';

enum OtlpSignal { traces, metrics, logs }

class OtlpExporterOptions {
  OtlpExporterOptions._(this.signal, this.endpoint, this.headers, this.timeout);

  factory OtlpExporterOptions.forSignal(OtlpSignal signal,
      {Uri? endpoint,
      Map<String, String>? headers,
      Duration? timeout}) {
    final resolvedEndpoint = endpoint ?? _resolveEndpoint(signal);
    final resolvedHeaders = _buildHeaders(signal, headers);
    final resolvedTimeout = timeout ??
        Environment.getDuration('OTEL_EXPORTER_OTLP_TIMEOUT') ??
        const Duration(seconds: 10);
    return OtlpExporterOptions._(
        signal, resolvedEndpoint, resolvedHeaders, resolvedTimeout);
  }

  final OtlpSignal signal;
  final Uri endpoint;
  final Map<String, String> headers;
  final Duration timeout;
}

String _signalName(OtlpSignal signal) {
  switch (signal) {
    case OtlpSignal.traces:
      return 'TRACES';
    case OtlpSignal.metrics:
      return 'METRICS';
    case OtlpSignal.logs:
      return 'LOGS';
  }
}

Uri _resolveEndpoint(OtlpSignal signal) {
  final signalName = _signalName(signal);
  final specific =
      Environment.getString('OTEL_EXPORTER_OTLP_${signalName}_ENDPOINT');
  final general = Environment.getString('OTEL_EXPORTER_OTLP_ENDPOINT');
  final defaultPath = _defaultPath(signal);
  final raw = specific ?? general ?? 'http://localhost:4318$defaultPath';
  final uri = Uri.parse(raw);
  if (uri.path.isEmpty || uri.path == '/') {
    return uri.replace(path: defaultPath);
  }
  return uri;
}

String _defaultPath(OtlpSignal signal) {
  switch (signal) {
    case OtlpSignal.traces:
      return '/v1/traces';
    case OtlpSignal.metrics:
      return '/v1/metrics';
    case OtlpSignal.logs:
      return '/v1/logs';
  }
}

Map<String, String> _buildHeaders(
    OtlpSignal signal, Map<String, String>? override) {
  final entries = <String, String>{
    'Content-Type': 'application/json',
  };
  final signalName = _signalName(signal);
  final envHeaders = Environment.getString(
          'OTEL_EXPORTER_OTLP_${signalName}_HEADERS') ??
      Environment.getString('OTEL_EXPORTER_OTLP_HEADERS');
  if (envHeaders != null && envHeaders.isNotEmpty) {
    for (final part in envHeaders.split(',')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final eqIndex = trimmed.indexOf('=');
      if (eqIndex <= 0) {
        continue;
      }
      final key = trimmed.substring(0, eqIndex).trim();
      final value = trimmed.substring(eqIndex + 1).trim();
      if (key.isEmpty || value.isEmpty) {
        continue;
      }
      entries[key] = value;
    }
  }
  if (override != null) {
    entries.addAll(override);
  }
  return entries;
}
