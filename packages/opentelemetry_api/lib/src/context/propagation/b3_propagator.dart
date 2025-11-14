import '../../context/context.dart';
import '../../trace/span.dart';
import '../../trace/span_context.dart';
import 'text_map_propagator.dart';

class B3Propagator extends TextMapPropagator {
  const B3Propagator({this.singleHeader = false});

  final bool singleHeader;

  static const _traceIdHeader = 'x-b3-traceid';
  static const _spanIdHeader = 'x-b3-spanid';
  static const _sampledHeader = 'x-b3-sampled';
  static const _singleHeader = 'b3';

  @override
  Iterable<String> get fields => singleHeader
      ? const [_singleHeader]
      : const [_traceIdHeader, _spanIdHeader, _sampledHeader];

  @override
  Context extract<T>(Context context, T carrier, TextMapGetter<T> getter) {
    if (singleHeader) {
      final header = getter.get(carrier, _singleHeader);
      if (header == null) {
        return context;
      }
      return _extractSingle(context, header);
    }
    final traceId = getter.get(carrier, _traceIdHeader);
    final spanId = getter.get(carrier, _spanIdHeader);
    if (traceId == null || spanId == null) {
      return context;
    }
    final sampledFlag = getter.get(carrier, _sampledHeader);
    return _buildContext(context, traceId, spanId, sampledFlag);
  }

  Context _extractSingle(Context context, String header) {
    final parts = header.split('-');
    if (parts.length < 2) {
      return context;
    }
    final traceId = parts[0];
    final spanId = parts[1];
    final sampled = parts.length >= 3 ? parts[2] : null;
    return _buildContext(context, traceId, spanId, sampled);
  }

  Context _buildContext(
      Context context, String traceIdHex, String spanIdHex, String? sampled) {
    try {
      final traceId = TraceId.fromHex(traceIdHex.padLeft(32, '0'));
      final spanId = SpanId.fromHex(spanIdHex.padLeft(16, '0'));
      final traceFlags =
          (sampled == '1' || sampled?.toLowerCase() == 'true')
              ? TraceFlags.sampled
              : TraceFlags.none;
      final spanContext = SpanContext(
        traceId: traceId,
        spanId: spanId,
        traceFlags: traceFlags,
        isRemote: true,
      );
      return context.withSpanContext(spanContext);
    } catch (_) {
      return context;
    }
  }

  @override
  void inject<T>(Context context, T carrier, TextMapSetter<T> setter) {
    final spanContext = context.spanContext;
    if (spanContext == null || !spanContext.isValid) {
      return;
    }
    final sampled = spanContext.isSampled ? '1' : '0';
    if (singleHeader) {
      final header =
          '${spanContext.traceId.value}-${spanContext.spanId.value}-$sampled';
      setter.set(carrier, _singleHeader, header);
      return;
    }
    setter.set(carrier, _traceIdHeader, spanContext.traceId.value);
    setter.set(carrier, _spanIdHeader, spanContext.spanId.value);
    setter.set(carrier, _sampledHeader, sampled);
  }
}
