import 'log_record.dart';
import 'log_exporter.dart';

abstract class LogRecordProcessor {
  void onEmit(LogRecord record);

  Future<void> forceFlush();

  Future<void> shutdown();
}

class SimpleLogRecordProcessor implements LogRecordProcessor {
  SimpleLogRecordProcessor(this._exporter);

  final LogRecordExporter _exporter;
  bool _isShutdown = false;

  @override
  void onEmit(LogRecord record) {
    if (_isShutdown) {
      return;
    }
    _exporter.export([record]);
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

class MultiLogRecordProcessor implements LogRecordProcessor {
  MultiLogRecordProcessor(this._processors);

  final List<LogRecordProcessor> _processors;

  @override
  void onEmit(LogRecord record) {
    for (final processor in _processors) {
      processor.onEmit(record);
    }
  }

  @override
  Future<void> forceFlush() async {
    for (final processor in _processors) {
      await processor.forceFlush();
    }
  }

  @override
  Future<void> shutdown() async {
    for (final processor in _processors) {
      await processor.shutdown();
    }
  }
}
