import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:opentelemetry_shared/opentelemetry_shared.dart';

import 'log_processor.dart';
import 'log_record.dart';
import '../resource/resource.dart';

class SdkLogger extends Logger {
  SdkLogger({
    required this.resource,
    required this.scope,
    required LogRecordProcessor processor,
  })  : _processor = processor,
        super(name: scope.name, version: scope.version, schemaUrl: scope.schemaUrl);

  final Resource resource;
  final InstrumentationScope scope;
  final LogRecordProcessor _processor;

  bool _isShutdown = false;

  void shutdown() {
    _isShutdown = true;
  }

  @override
  void emit(LogRecordData record) {
    if (_isShutdown) {
      return;
    }
    final context = Context.current;
    final logRecord = LogRecord(
      resource: resource,
      instrumentationScope: scope,
      data: record,
      context: context,
    );
    _processor.onEmit(logRecord);
  }
}
