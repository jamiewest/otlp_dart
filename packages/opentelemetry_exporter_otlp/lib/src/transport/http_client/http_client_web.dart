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
    return HttpResponse(response.statusCode);
  }

  @override
  Future<void> close() async {
    _client.close();
  }
}

HttpClient createHttpClient() => WebHttpClient();
