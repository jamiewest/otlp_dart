import '../resource/resource.dart';
import 'log_exporter.dart';
import 'log_processor.dart';
import 'sdk_logger_provider.dart';

class SdkLoggerProviderBuilder {
  final List<LogRecordProcessor> _processors = [];
  Resource _resource = Resource.defaultResource();

  SdkLoggerProviderBuilder addLogRecordProcessor(LogRecordProcessor processor) {
    _processors.add(processor);
    return this;
  }

  SdkLoggerProviderBuilder addLogRecordExporter(LogRecordExporter exporter) {
    return addLogRecordProcessor(SimpleLogRecordProcessor(exporter));
  }

  SdkLoggerProviderBuilder setResource(Resource resource) {
    _resource = resource;
    return this;
  }

  SdkLoggerProvider build() {
    final processor = _processors.isEmpty
        ? SimpleLogRecordProcessor(const NoopLogRecordExporter())
        : _processors.length == 1
            ? _processors.first
            : MultiLogRecordProcessor(List.unmodifiable(_processors));
    return SdkLoggerProvider(resource: _resource, processor: processor);
  }
}
