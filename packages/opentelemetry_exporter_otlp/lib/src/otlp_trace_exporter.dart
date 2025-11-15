import 'dart:typed_data';

import 'package:opentelemetry/opentelemetry.dart';
import 'package:grpc/src/client/method.dart' show ClientMethod;
import 'package:shared/shared.dart';
import 'package:otlp_dart/src/proto/opentelemetry/proto/collector/trace/v1/trace_service.pb.dart'
    as otlp_trace_service;

import 'otlp_encoding.dart';
import 'otlp_grpc_sender.dart';
import 'otlp_http_sender.dart';
import 'otlp_options.dart';
import 'transport/http_client/http_client.dart';

class OtlpTraceExporter extends SpanExporter {
  OtlpTraceExporter({
    OtlpExporterOptions? options,
    HttpClient? httpClient,
    RetryPolicy? retryPolicy,
  }) : _options = options ?? OtlpExporterOptions.forSignal(OtlpSignal.traces) {
    if (_options.protocol == OtlpProtocol.grpc) {
      _grpcSender = OtlpGrpcSender<
          otlp_trace_service.ExportTraceServiceRequest,
          otlp_trace_service.ExportTraceServiceResponse>(
        options: _options,
        method: _traceExportMethod,
        retryPolicy: retryPolicy,
      );
    } else {
      _httpSender = OtlpHttpSender(
        options: _options,
        client: httpClient,
        retryPolicy: retryPolicy,
      );
    }
  }

  final OtlpExporterOptions _options;
  OtlpHttpSender? _httpSender;
  OtlpGrpcSender<otlp_trace_service.ExportTraceServiceRequest,
      otlp_trace_service.ExportTraceServiceResponse>? _grpcSender;
  bool _isShutdown = false;

  @override
  Future<ExportResult> export(List<SpanData> spans) async {
    if (_isShutdown || spans.isEmpty) {
      return ExportResult.success;
    }
    final request = buildTraceRequest(spans);
    if (_options.protocol == OtlpProtocol.grpc) {
      return _grpcSender!.send(request);
    }
    final payload = Uint8List.fromList(request.writeToBuffer());
    return _httpSender!.send(payload);
  }

  @override
  Future<void> shutdown() async {
    if (_isShutdown) {
      return;
    }
    _isShutdown = true;
    await _grpcSender?.shutdown();
    await _httpSender?.shutdown();
  }
}

final _traceExportMethod = ClientMethod<
        otlp_trace_service.ExportTraceServiceRequest,
        otlp_trace_service.ExportTraceServiceResponse>(
  '/opentelemetry.proto.collector.trace.v1.TraceService/Export',
  (request) => request.writeToBuffer(),
  (bytes) => otlp_trace_service.ExportTraceServiceResponse.fromBuffer(bytes),
);
