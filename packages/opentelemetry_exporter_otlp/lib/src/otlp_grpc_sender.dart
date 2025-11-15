import 'dart:async';

import 'package:grpc/grpc_or_grpcweb.dart';
import 'package:grpc/src/client/client.dart' show Client;
import 'package:grpc/src/client/method.dart' show ClientMethod;
import 'package:opentelemetry/opentelemetry.dart';
import 'package:shared/shared.dart';

import 'otlp_options.dart';

class OtlpGrpcSender<Request, Response> {
  OtlpGrpcSender({
    required OtlpExporterOptions options,
    required ClientMethod<Request, Response> method,
    RetryPolicy? retryPolicy,
  })  : _options = options,
        _method = method,
        _retryPolicy = retryPolicy ??
            const RetryPolicy(maxAttempts: 5, initialBackoff: Duration(milliseconds: 500)),
        _channel = GrpcOrGrpcWebClientChannel.toSingleEndpoint(
          host: _hostFromUri(options.endpoint),
          port: _portFromUri(options.endpoint, options.useTls),
          transportSecure: options.useTls,
        );

  final OtlpExporterOptions _options;
  final ClientMethod<Request, Response> _method;
  final RetryPolicy _retryPolicy;
  final GrpcOrGrpcWebClientChannel _channel;

  Future<ExportResult> send(Request request) async {
    try {
      await _retryPolicy.execute((_) async {
        final callOptions = CallOptions(
          timeout: _options.timeout,
          metadata: _options.headers.isEmpty ? null : _options.headers,
        );
        final client = _GrpcInvoker<Request, Response>(_channel);
        await client.unary(_method, request, callOptions);
      }, shouldRetry: _isRetryableError);
      return ExportResult.success;
    } catch (_) {
      return ExportResult.failure;
    }
  }

  Future<void> shutdown() async {
    await _channel.shutdown();
  }

  bool _isRetryableError(Object error) {
    if (error is GrpcError) {
      return error.code == StatusCode.unavailable ||
          error.code == StatusCode.deadlineExceeded ||
          error.code == StatusCode.resourceExhausted;
    }
    return false;
  }

  static String _hostFromUri(Uri uri) {
    if (uri.host.isNotEmpty) {
      return uri.host;
    }
    return 'localhost';
  }

  static int _portFromUri(Uri uri, bool useTls) {
    if (uri.hasPort && uri.port != 0) {
      return uri.port;
    }
    return useTls ? 443 : 80;
  }
}

class _GrpcInvoker<Q, R> extends Client {
  _GrpcInvoker(GrpcOrGrpcWebClientChannel channel) : super(channel);

  ResponseFuture<R> unary(
    ClientMethod<Q, R> method,
    Q request,
    CallOptions options,
  ) {
    return $createUnaryCall(method, request, options: options);
  }
}
