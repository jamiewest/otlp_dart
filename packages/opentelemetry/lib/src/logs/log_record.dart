import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:shared/shared.dart';

import '../resource/resource.dart';

class LogRecord {
  LogRecord({
    required this.resource,
    required this.instrumentationScope,
    required this.data,
    required this.context,
  });

  final Resource resource;
  final InstrumentationScope instrumentationScope;
  final LogRecordData data;
  final Context context;

  SpanContext? get spanContext =>
      context.spanContext ?? data.spanContext ?? Context.current.spanContext;
}
