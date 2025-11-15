import 'dart:typed_data';

import 'package:opentelemetry/opentelemetry.dart';
import 'package:grpc/src/client/method.dart' show ClientMethod;
import 'package:shared/shared.dart';
import 'package:otlp_dart/src/proto/opentelemetry/proto/collector/metrics/v1/metrics_service.pb.dart'
    as otlp_metrics_service;

import 'otlp_encoding.dart';
import 'otlp_grpc_sender.dart';
import 'otlp_http_sender.dart';
import 'otlp_options.dart';
import 'transport/http_client/http_client.dart';

class OtlpMetricExporter extends MetricExporter {
  OtlpMetricExporter({
    OtlpExporterOptions? options,
    HttpClient? httpClient,
    RetryPolicy? retryPolicy,
  }) : _options = options ?? OtlpExporterOptions.forSignal(OtlpSignal.metrics) {
    if (_options.protocol == OtlpProtocol.grpc) {
      _grpcSender = OtlpGrpcSender<
          otlp_metrics_service.ExportMetricsServiceRequest,
          otlp_metrics_service.ExportMetricsServiceResponse>(
        options: _options,
        method: _metricExportMethod,
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
  OtlpGrpcSender<otlp_metrics_service.ExportMetricsServiceRequest,
      otlp_metrics_service.ExportMetricsServiceResponse>? _grpcSender;
  bool _isShutdown = false;

  @override
  Future<ExportResult> export(List<MetricData> metrics) async {
    if (_isShutdown || metrics.isEmpty) {
      return ExportResult.success;
    }
    final request = buildMetricRequest(metrics);
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

final _metricExportMethod = ClientMethod<
        otlp_metrics_service.ExportMetricsServiceRequest,
        otlp_metrics_service.ExportMetricsServiceResponse>(
  '/opentelemetry.proto.collector.metrics.v1.MetricsService/Export',
  (request) => request.writeToBuffer(),
  (bytes) => otlp_metrics_service.ExportMetricsServiceResponse.fromBuffer(bytes),
);
