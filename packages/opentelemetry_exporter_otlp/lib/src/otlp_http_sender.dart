import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:opentelemetry/opentelemetry.dart';
import 'package:shared/shared.dart';

import 'otlp_options.dart';

class _RetryableException implements Exception {
  _RetryableException(this.statusCode);

  final int statusCode;
}

class _NonRetryableException implements Exception {
  _NonRetryableException(this.statusCode);

  final int statusCode;
}

class OtlpHttpSender {
  OtlpHttpSender({
    required OtlpExporterOptions options,
    http.Client? client,
    RetryPolicy? retryPolicy,
  })  : _options = options,
        _client = client ?? http.Client(),
        _ownsClient = client == null,
        _retryPolicy = retryPolicy ??
            const RetryPolicy(maxAttempts: 5, initialBackoff: Duration(milliseconds: 500));

  final OtlpExporterOptions _options;
  final http.Client _client;
  final bool _ownsClient;
  final RetryPolicy _retryPolicy;

  Future<ExportResult> send(Uint8List payload) async {
    try {
      await _retryPolicy.execute((_) async {
        final headers = {
          'content-type': 'application/x-protobuf',
          ..._options.headers,
        };
        final response = await _client
            .post(_options.endpoint, headers: headers, body: payload)
            .timeout(_options.timeout);
        if (_isSuccess(response.statusCode)) {
          return;
        }
        if (!_shouldRetry(response.statusCode)) {
          throw _NonRetryableException(response.statusCode);
        }
        throw _RetryableException(response.statusCode);
      }, shouldRetry: (error) => error is _RetryableException);
      return ExportResult.success;
    } catch (_) {
      return ExportResult.failure;
    }
  }

  Future<void> shutdown() async {
    if (_ownsClient) {
      _client.close();
    }
  }

  bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

  bool _shouldRetry(int statusCode) {
    if (statusCode == 408 || statusCode == 429) {
      return true;
    }
    return statusCode >= 500 && statusCode < 600;
  }
}
