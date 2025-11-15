import 'dart:async';
import 'dart:typed_data';

import 'package:http/browser_client.dart' as http;

import 'http_client_stub.dart';

class WebHttpClient implements HttpClient {
  WebHttpClient() : _client = http.BrowserClient();

  final http.BrowserClient _client;

  @override
  Future<HttpResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required Uint8List body,
    required Duration timeout,
  }) async {
    final response = await _client
        .post(uri, headers: headers, body: body)
        .timeout(timeout);

    // Read body for non-success responses (for debugging)
    String? responseBody;
    if (response.statusCode >= 400) {
      try {
        responseBody = response.body;
        // Limit body size to prevent memory issues
        if (responseBody.length > 1000) {
          responseBody = '${responseBody.substring(0, 1000)}... (truncated)';
        }
      } catch (_) {
        // Ignore errors reading response body
      }
    }

    return HttpResponse(response.statusCode, body: responseBody);
  }

  @override
  Future<void> close() async {
    _client.close();
  }
}

HttpClient createHttpClient() => WebHttpClient();
