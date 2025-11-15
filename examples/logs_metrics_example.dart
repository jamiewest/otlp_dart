import 'dart:async';

import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:opentelemetry_exporter_console/opentelemetry_exporter_console.dart';
import 'package:opentelemetry/opentelemetry.dart';

Future<void> main() async {
  final meterProvider = SdkMeterProviderBuilder()
      .addMetricExporter(ConsoleMetricExporter(),
          exportInterval: const Duration(seconds: 2))
      .build();
  final meter = meterProvider.getMeter('example-metrics');
  final counter = meter.createCounter('jobs.processed', description: 'Jobs');
  counter.add(5, attributes: {'worker': 'A'});

  final loggerProvider = SdkLoggerProviderBuilder()
      .addLogRecordExporter(ConsoleLogExporter())
      .build();
  final logger = loggerProvider.getLogger('example-logs');
  logger.log('example log entry',
      attributes: {'component': 'example'},
      severity: LogRecordSeverity.info);

  await Future<void>.delayed(const Duration(seconds: 3));
  await Future.wait([meterProvider.shutdown(), loggerProvider.shutdown()]);
}
