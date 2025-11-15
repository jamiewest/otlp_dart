import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'http_client_stub.dart';

class IoHttpClient implements HttpClient {
  IoHttpClient() : _client = http.Client();

  final http.Client _client;

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

HttpClient createHttpClient() => IoHttpClient();
