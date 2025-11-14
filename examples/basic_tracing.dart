import 'package:opentelemetry_exporter_console/opentelemetry_exporter_console.dart';
import 'package:opentelemetry_sdk/opentelemetry_sdk.dart';

Future<void> main() async {
  final tracerProvider = SdkTracerProviderBuilder()
      .addSpanProcessor(SimpleSpanProcessor(ConsoleSpanExporter()))
      .build();

  final tracer = tracerProvider.getTracer('example', version: '0.1.0');

  final span = tracer.startSpan('demo-span');
  tracer.withSpan(span, () {
    span.setAttribute('component', 'example');
    span.addEvent('processing');
    span.addEvent('finishing');
  });
  span.end();

  await tracerProvider.shutdown();
}
