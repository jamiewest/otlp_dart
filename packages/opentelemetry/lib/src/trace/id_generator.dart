import 'package:opentelemetry_api/opentelemetry_api.dart';

abstract class IdGenerator {
  TraceId newTraceId();
  SpanId newSpanId();
}

class RandomIdGenerator implements IdGenerator {
  const RandomIdGenerator();

  @override
  SpanId newSpanId() => SpanId.random();

  @override
  TraceId newTraceId() => TraceId.random();
}
