import 'package:opentelemetry_api/opentelemetry_api.dart';

import 'export_result.dart';
import 'sdk_span.dart';
import 'span_exporter.dart';

abstract class SpanProcessor {
  void onStart(ReadableSpan span, Context parentContext) {}

  Future<void> onEnd(ReadableSpan span);

  Future<void> shutdown();

  Future<void> forceFlush();
}

class SimpleSpanProcessor implements SpanProcessor {
  SimpleSpanProcessor(this._exporter);

  final SpanExporter _exporter;
  bool _isShutdown = false;

  @override
  void onStart(ReadableSpan span, Context parentContext) {}

  @override
  Future<void> onEnd(ReadableSpan span) async {
    if (_isShutdown) {
      return;
    }
    final result = await _exporter.export([span.toSpanData()]);
    if (result == ExportResult.failure) {
      // Drop spans on failure similar to .NET default behavior.
    }
  }

  @override
  Future<void> shutdown() async {
    if (_isShutdown) {
      return;
    }
    _isShutdown = true;
    await _exporter.shutdown();
  }

  @override
  Future<void> forceFlush() => _exporter.forceFlush();
}

class MultiSpanProcessor implements SpanProcessor {
  MultiSpanProcessor(this._processors);

  final List<SpanProcessor> _processors;

  @override
  void onStart(ReadableSpan span, Context parentContext) {
    for (final processor in _processors) {
      processor.onStart(span, parentContext);
    }
  }

  @override
  Future<void> onEnd(ReadableSpan span) async {
    for (final processor in _processors) {
      await processor.onEnd(span);
    }
  }

  @override
  Future<void> shutdown() async {
    for (final processor in _processors) {
      await processor.shutdown();
    }
  }

  @override
  Future<void> forceFlush() async {
    for (final processor in _processors) {
      await processor.forceFlush();
    }
  }
}
