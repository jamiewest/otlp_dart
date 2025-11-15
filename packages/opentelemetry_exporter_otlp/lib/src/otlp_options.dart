import 'package:shared/shared.dart';

enum OtlpSignal { traces, metrics, logs }

enum OtlpProtocol { grpc, httpProtobuf }

class OtlpExporterOptions {
  OtlpExporterOptions._(
    this.signal,
    this.protocol,
    this.endpoint,
    this.headers,
    this.timeout,
  );

  factory OtlpExporterOptions.forSignal(
    OtlpSignal signal, {
    Uri? endpoint,
    Map<String, String>? headers,
    Duration? timeout,
    OtlpProtocol? protocol,
  }) {
    final resolvedProtocol = protocol ?? _resolveProtocol(signal);
    final resolvedEndpoint = endpoint ?? _resolveEndpoint(signal, resolvedProtocol);
    final resolvedHeaders = _buildHeaders(signal, headers);
    final resolvedTimeout = timeout ??
        Environment.getDuration('OTEL_EXPORTER_OTLP_TIMEOUT') ??
        const Duration(seconds: 10);
    return OtlpExporterOptions._(
      signal,
      resolvedProtocol,
      resolvedEndpoint,
      resolvedHeaders,
      resolvedTimeout,
    );
  }

  final OtlpSignal signal;
  final OtlpProtocol protocol;
  final Uri endpoint;
  final Map<String, String> headers;
  final Duration timeout;

  bool get useTls =>
      endpoint.scheme.toLowerCase().startsWith('https') ||
      endpoint.scheme.toLowerCase().startsWith('grpcs');
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

OtlpProtocol _resolveProtocol(OtlpSignal signal) {
  final signalName = _signalName(signal);
  final specific =
      Environment.getString('OTEL_EXPORTER_OTLP_${signalName}_PROTOCOL');
  final general = Environment.getString('OTEL_EXPORTER_OTLP_PROTOCOL');
  final candidate = specific ?? general;
  if (candidate == null) {
    return OtlpProtocol.grpc;
  }
  final parsed = _parseProtocol(candidate);
  return parsed ?? OtlpProtocol.grpc;
}

OtlpProtocol? _parseProtocol(String raw) {
  final value = raw.trim().toLowerCase();
  switch (value) {
    case 'grpc':
      return OtlpProtocol.grpc;
    case 'http/protobuf':
    case 'http_protobuf':
    case 'http':
      return OtlpProtocol.httpProtobuf;
    default:
      return null;
  }
}

Uri _resolveEndpoint(OtlpSignal signal, OtlpProtocol protocol) {
  final signalName = _signalName(signal);
  final specific =
      Environment.getString('OTEL_EXPORTER_OTLP_${signalName}_ENDPOINT');
  final general = Environment.getString('OTEL_EXPORTER_OTLP_ENDPOINT');
  final raw = specific ??
      general ??
      (protocol == OtlpProtocol.grpc
          ? 'http://localhost:4317'
          : 'http://localhost:4318${_defaultPath(signal)}');
  final uri = Uri.parse(raw);

  if (protocol == OtlpProtocol.httpProtobuf) {
    final defaultPath = _defaultPath(signal);
    if (uri.path.isEmpty || uri.path == '/') {
      return uri.replace(path: defaultPath);
    }
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
  final entries = <String, String>{};
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
      entries[Uri.decodeComponent(key)] = Uri.decodeComponent(value);
    }
  }
  if (override != null) {
    entries.addAll(override);
  }
  return entries;
}
