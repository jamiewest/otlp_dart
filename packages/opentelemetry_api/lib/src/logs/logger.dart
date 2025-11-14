import '../trace/attributes.dart';
import 'log_record.dart';
import 'log_record_severity.dart';

abstract class Logger {
  const Logger({required this.name, this.version, this.schemaUrl});

  final String name;
  final String? version;
  final String? schemaUrl;

  void emit(LogRecordData record);

  void log(String body,
      {LogRecordSeverity severity = LogRecordSeverity.info,
      Map<String, AttributeValue> attributes = const {},
      DateTime? timestamp,
      DateTime? observedTimestamp}) {
    emit(LogRecordData(
      body: body,
      severity: severity,
      attributes: attributes,
      timestamp: timestamp,
      observedTimestamp: observedTimestamp,
    ));
  }
}

class NoopLogger extends Logger {
  const NoopLogger() : super(name: 'noop');

  @override
  void emit(LogRecordData record) {}
}
