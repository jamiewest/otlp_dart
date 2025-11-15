import 'dart:async';
import 'dart:typed_data';

abstract class HttpClient {
  Future<HttpResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required Uint8List body,
    required Duration timeout,
  });

  Future<void> close();
}

class HttpResponse {
  HttpResponse(this.statusCode);
  final int statusCode;
}

HttpClient createHttpClient() =>
    throw UnsupportedError('HTTP transport is not supported on this platform');
