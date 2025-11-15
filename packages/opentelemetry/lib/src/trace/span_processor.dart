import 'dart:async';
import 'dart:collection';

import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:shared/shared.dart';

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

/// A [SpanProcessor] that batches spans and exports them periodically.
///
/// This processor is recommended for production use as it:
/// - Reduces network overhead by batching multiple spans
/// - Minimizes latency impact on span completion
/// - Provides bounded memory usage through queue size limits
///
/// The processor maintains an internal queue of spans and exports them when:
/// - The batch size limit is reached
/// - The scheduled timer fires
/// - [forceFlush] is called
/// - [shutdown] is called
///
/// ## Environment Variables
///
/// The processor can be configured using OpenTelemetry environment variables:
/// - `OTEL_BSP_MAX_QUEUE_SIZE`: Maximum queue size (default: 2048)
/// - `OTEL_BSP_MAX_EXPORT_BATCH_SIZE`: Maximum batch size (default: 512)
/// - `OTEL_BSP_SCHEDULE_DELAY`: Delay in milliseconds (default: 5000)
/// - `OTEL_BSP_EXPORT_TIMEOUT`: Timeout in milliseconds (default: 30000)
///
/// Example:
/// ```dart
/// // Manual configuration
/// final processor = BatchSpanProcessor(
///   exporter,
///   maxQueueSize: 2048,
///   maxExportBatchSize: 512,
///   scheduledDelay: Duration(seconds: 5),
/// );
///
/// // From environment variables
/// final processor = BatchSpanProcessor.fromEnvironment(exporter);
/// ```
class BatchSpanProcessor implements SpanProcessor {
  static const int _defaultMaxQueueSize = 2048;
  static const int _defaultMaxExportBatchSize = 512;
  static const Duration _defaultScheduledDelay = Duration(milliseconds: 5000);
  static const Duration _defaultExportTimeout = Duration(milliseconds: 30000);

  /// Creates a [BatchSpanProcessor] with the given configuration.
  ///
  /// Parameters:
  /// - [exporter]: The exporter to send batched spans to
  /// - [maxQueueSize]: Maximum number of spans to queue (default: 2048)
  /// - [maxExportBatchSize]: Maximum number of spans per batch (default: 512)
  /// - [scheduledDelay]: Delay between periodic exports (default: 5000ms)
  /// - [exportTimeout]: Timeout for export operations (default: 30000ms)
  /// - [logger]: Optional logger for diagnostics
  ///
  /// Throws [ArgumentError] if configuration parameters are invalid.
  BatchSpanProcessor(
    this._exporter, {
    int maxQueueSize = _defaultMaxQueueSize,
    int maxExportBatchSize = _defaultMaxExportBatchSize,
    Duration scheduledDelay = _defaultScheduledDelay,
    Duration exportTimeout = _defaultExportTimeout,
    TelemetryLogger? logger,
  })  : _maxQueueSize = maxQueueSize,
        _maxExportBatchSize = maxExportBatchSize,
        _scheduledDelay = scheduledDelay,
        _exportTimeout = exportTimeout,
        _logger = logger ?? const NoOpTelemetryLogger() {
    // Validate configuration parameters
    if (maxQueueSize <= 0) {
      throw ArgumentError.value(
        maxQueueSize,
        'maxQueueSize',
        'must be positive',
      );
    }
    if (maxExportBatchSize <= 0) {
      throw ArgumentError.value(
        maxExportBatchSize,
        'maxExportBatchSize',
        'must be positive',
      );
    }
    if (maxExportBatchSize > maxQueueSize) {
      throw ArgumentError(
        'maxExportBatchSize ($maxExportBatchSize) cannot exceed '
        'maxQueueSize ($maxQueueSize)',
      );
    }
    if (scheduledDelay.isNegative) {
      throw ArgumentError.value(
        scheduledDelay,
        'scheduledDelay',
        'cannot be negative',
      );
    }
    if (exportTimeout.isNegative) {
      throw ArgumentError.value(
        exportTimeout,
        'exportTimeout',
        'cannot be negative',
      );
    }

    _logger.debug(
      'BatchSpanProcessor initialized: maxQueueSize=$maxQueueSize, '
      'maxExportBatchSize=$maxExportBatchSize, '
      'scheduledDelay=${scheduledDelay.inMilliseconds}ms, '
      'exportTimeout=${exportTimeout.inMilliseconds}ms',
    );

    _timer = Timer.periodic(_scheduledDelay, (_) => _exportBatch());
  }

  /// Creates a [BatchSpanProcessor] configured from environment variables.
  ///
  /// This factory method reads configuration from the following environment
  /// variables, following the OpenTelemetry specification:
  /// - `OTEL_BSP_MAX_QUEUE_SIZE`: Maximum queue size
  /// - `OTEL_BSP_MAX_EXPORT_BATCH_SIZE`: Maximum batch size
  /// - `OTEL_BSP_SCHEDULE_DELAY`: Delay in milliseconds
  /// - `OTEL_BSP_EXPORT_TIMEOUT`: Timeout in milliseconds
  ///
  /// If a variable is not set or invalid, the default value is used.
  factory BatchSpanProcessor.fromEnvironment(
    SpanExporter exporter, {
    EnvironmentReader? envReader,
    TelemetryLogger? logger,
  }) {
    final env = envReader ?? const EnvironmentReader();

    final maxQueueSize = env.getInt('OTEL_BSP_MAX_QUEUE_SIZE') ??
        _defaultMaxQueueSize;
    final maxExportBatchSize =
        env.getInt('OTEL_BSP_MAX_EXPORT_BATCH_SIZE') ??
            _defaultMaxExportBatchSize;
    final scheduledDelayMs = env.getInt('OTEL_BSP_SCHEDULE_DELAY') ??
        _defaultScheduledDelay.inMilliseconds;
    final exportTimeoutMs = env.getInt('OTEL_BSP_EXPORT_TIMEOUT') ??
        _defaultExportTimeout.inMilliseconds;

    return BatchSpanProcessor(
      exporter,
      maxQueueSize: maxQueueSize,
      maxExportBatchSize: maxExportBatchSize,
      scheduledDelay: Duration(milliseconds: scheduledDelayMs),
      exportTimeout: Duration(milliseconds: exportTimeoutMs),
      logger: logger,
    );
  }

  final SpanExporter _exporter;
  final int _maxQueueSize;
  final int _maxExportBatchSize;
  final Duration _scheduledDelay;
  final Duration _exportTimeout;
  final TelemetryLogger _logger;

  final Queue<SpanData> _queue = Queue<SpanData>();
  Timer? _timer;
  bool _isShutdown = false;
  Completer<void>? _flushCompleter;
  bool _isExporting = false;

  // Metrics
  int _droppedSpans = 0;
  int _exportedBatches = 0;
  int _failedExports = 0;

  /// Number of spans dropped due to queue being full.
  int get droppedSpans => _droppedSpans;

  /// Number of batches successfully exported.
  int get exportedBatches => _exportedBatches;

  /// Number of export operations that failed.
  int get failedExports => _failedExports;

  /// Current number of spans in the queue.
  int get queueSize => _queue.length;

  @override
  void onStart(ReadableSpan span, Context parentContext) {}

  @override
  Future<void> onEnd(ReadableSpan span) async {
    if (_isShutdown) {
      return;
    }

    if (_queue.length >= _maxQueueSize) {
      // Drop span when queue is full
      _droppedSpans++;
      if (_droppedSpans == 1 || _droppedSpans % 1000 == 0) {
        _logger.warning(
          'Span queue is full (size: $_maxQueueSize). '
          'Dropped $_droppedSpans spans so far. '
          'Consider increasing maxQueueSize or reducing span creation rate.',
        );
      }
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
        _logger.debug('Exporting batch of ${batch.length} spans');
        try {
          final result = await _exporter.export(batch).timeout(_exportTimeout);
          if (result == ExportResult.success) {
            _exportedBatches++;
            _logger.debug(
              'Successfully exported batch of ${batch.length} spans '
              '(total batches: $_exportedBatches)',
            );
          } else {
            _failedExports++;
            _logger.error(
              'Failed to export batch of ${batch.length} spans. '
              'Exporter returned failure. '
              'Total failed exports: $_failedExports',
            );
          }
        } on TimeoutException catch (e, stackTrace) {
          _failedExports++;
          _logger.error(
            'Export timeout after ${_exportTimeout.inMilliseconds}ms '
            'for batch of ${batch.length} spans',
            e,
            stackTrace,
          );
        } catch (e, stackTrace) {
          _failedExports++;
          _logger.error(
            'Exception during export of batch with ${batch.length} spans',
            e,
            stackTrace,
          );
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
      _logger.warning('forceFlush called on shutdown processor');
      return;
    }

    _logger.debug('Force flushing BatchSpanProcessor');
    final startQueueSize = _queue.length;

    while (_queue.isNotEmpty) {
      await _exportBatch();
    }

    await _exporter.forceFlush();
    _logger.debug('Force flush completed ($startQueueSize spans flushed)');
  }

  @override
  Future<void> shutdown() async {
    if (_isShutdown) {
      _logger.debug('Shutdown called on already shutdown processor');
      return;
    }

    _logger.info('Shutting down BatchSpanProcessor');
    _isShutdown = true;

    // Cancel timer first
    _timer?.cancel();
    _timer = null;

    // Wait for any ongoing export to complete
    while (_isExporting) {
      await Future.delayed(const Duration(milliseconds: 10));
    }

    // Export remaining spans
    final remainingSpans = _queue.length;
    while (_queue.isNotEmpty) {
      await _exportBatch();
    }

    await _exporter.shutdown();

    _logger.info(
      'BatchSpanProcessor shutdown complete. '
      'Statistics: exported=$_exportedBatches batches, '
      'failed=$_failedExports exports, dropped=$_droppedSpans spans, '
      'flushed on shutdown=$remainingSpans spans',
    );
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
