import 'dart:async';
import 'dart:collection';

import 'package:opentelemetry_api/opentelemetry_api.dart';

import 'export_result.dart';
import 'sdk_span.dart';
import 'span_data.dart';
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

class BatchSpanProcessor implements SpanProcessor {
  BatchSpanProcessor(
    this._exporter, {
    int maxQueueSize = 2048,
    int maxExportBatchSize = 512,
    Duration scheduledDelay = const Duration(milliseconds: 5000),
    Duration exportTimeout = const Duration(milliseconds: 30000),
  })  : _maxQueueSize = maxQueueSize,
        _maxExportBatchSize = maxExportBatchSize,
        _scheduledDelay = scheduledDelay,
        _exportTimeout = exportTimeout {
    _timer = Timer.periodic(_scheduledDelay, (_) => _exportBatch());
  }

  final SpanExporter _exporter;
  final int _maxQueueSize;
  final int _maxExportBatchSize;
  final Duration _scheduledDelay;
  final Duration _exportTimeout;

  final Queue<SpanData> _queue = Queue<SpanData>();
  Timer? _timer;
  bool _isShutdown = false;
  Completer<void>? _flushCompleter;
  bool _isExporting = false;

  @override
  void onStart(ReadableSpan span, Context parentContext) {}

  @override
  Future<void> onEnd(ReadableSpan span) async {
    if (_isShutdown) {
      return;
    }

    if (_queue.length >= _maxQueueSize) {
      // Drop span when queue is full
      return;
    }

    _queue.add(span.toSpanData());

    // Export immediately if batch is full
    if (_queue.length >= _maxExportBatchSize) {
      await _exportBatch();
    }
  }

  Future<void> _exportBatch() async {
    if (_queue.isEmpty) {
      return;
    }

    // Prevent concurrent exports
    if (_isExporting) {
      return;
    }

    _isExporting = true;

    try {
      final batch = <SpanData>[];
      final batchSize = _queue.length > _maxExportBatchSize
          ? _maxExportBatchSize
          : _queue.length;

      for (var i = 0; i < batchSize; i++) {
        if (_queue.isEmpty) break;
        batch.add(_queue.removeFirst());
      }

      if (batch.isNotEmpty) {
        try {
          await _exporter.export(batch).timeout(_exportTimeout);
        } catch (e) {
          // Log error but continue processing
        }
      }

      // Complete flush if waiting
      if (_queue.isEmpty && _flushCompleter != null) {
        _flushCompleter!.complete();
        _flushCompleter = null;
      }
    } finally {
      _isExporting = false;
    }
  }

  @override
  Future<void> forceFlush() async {
    if (_isShutdown) {
      return;
    }

    while (_queue.isNotEmpty) {
      await _exportBatch();
    }

    await _exporter.forceFlush();
  }

  @override
  Future<void> shutdown() async {
    if (_isShutdown) {
      return;
    }

    _isShutdown = true;

    // Cancel timer first
    _timer?.cancel();
    _timer = null;

    // Wait for any ongoing export to complete
    while (_isExporting) {
      await Future.delayed(const Duration(milliseconds: 10));
    }

    // Export remaining spans
    while (_queue.isNotEmpty) {
      await _exportBatch();
    }

    await _exporter.shutdown();
  }
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
