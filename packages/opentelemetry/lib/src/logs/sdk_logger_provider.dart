import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:shared/shared.dart';

import '../resource/resource.dart';
import 'log_processor.dart';
import 'sdk_logger.dart';

class SdkLoggerProvider implements LoggerProvider {
  SdkLoggerProvider({
    required this.resource,
    required LogRecordProcessor processor,
  }) : _processor = processor;

  final Resource resource;
  final LogRecordProcessor _processor;
  final Map<InstrumentationScope, SdkLogger> _loggers = {};
  bool _isShutdown = false;

  @override
  Logger getLogger(String name, {String? version, String? schemaUrl}) {
    final scope =
        InstrumentationScope(name, version: version, schemaUrl: schemaUrl);
    return _loggers.putIfAbsent(
        scope,
        () => SdkLogger(
            resource: resource, scope: scope, processor: _processor));
  }

  @override
  Future<void> forceFlush() => _processor.forceFlush();

  @override
  Future<void> shutdown() async {
    if (_isShutdown) {
      return;
    }
    _isShutdown = true;
    for (final logger in _loggers.values) {
      logger.shutdown();
    }
    await _processor.shutdown();
  }
}
