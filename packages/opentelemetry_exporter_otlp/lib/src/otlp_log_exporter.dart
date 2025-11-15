import 'dart:typed_data';

import 'package:grpc/grpc.dart';
import 'package:http/http.dart' as http;
import 'package:opentelemetry/opentelemetry.dart';
import 'package:shared/shared.dart';
import 'package:otlp_dart/src/proto/opentelemetry/proto/collector/logs/v1/logs_service.pb.dart'
    as otlp_logs_service;

import 'otlp_encoding.dart';
import 'otlp_grpc_sender.dart';
import 'otlp_http_sender.dart';
import 'otlp_options.dart';

class OtlpLogExporter extends LogRecordExporter {
  OtlpLogExporter({
    OtlpExporterOptions? options,
    http.Client? httpClient,
    RetryPolicy? retryPolicy,
  }) : _options = options ?? OtlpExporterOptions.forSignal(OtlpSignal.logs) {
    if (_options.protocol == OtlpProtocol.grpc) {
      _grpcSender = OtlpGrpcSender<
          otlp_logs_service.ExportLogsServiceRequest,
          otlp_logs_service.ExportLogsServiceResponse>(
        options: _options,
        method: _logsExportMethod,
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
  OtlpGrpcSender<otlp_logs_service.ExportLogsServiceRequest,
      otlp_logs_service.ExportLogsServiceResponse>? _grpcSender;
  bool _isShutdown = false;

  @override
  Future<ExportResult> export(List<LogRecord> records) async {
    if (_isShutdown || records.isEmpty) {
      return ExportResult.success;
    }
    final request = buildLogRequest(records);
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

final _logsExportMethod = ClientMethod<
        otlp_logs_service.ExportLogsServiceRequest,
        otlp_logs_service.ExportLogsServiceResponse>(
  '/opentelemetry.proto.collector.logs.v1.LogsService/Export',
  (request) => request.writeToBuffer(),
  (bytes) => otlp_logs_service.ExportLogsServiceResponse.fromBuffer(bytes),
);
