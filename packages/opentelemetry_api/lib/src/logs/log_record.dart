import '../trace/attributes.dart';
import '../trace/span_context.dart';
import 'log_record_severity.dart';

class LogRecordData {
  LogRecordData({
    required this.body,
    LogRecordSeverity? severity,
    this.severityText,
    DateTime? timestamp,
    DateTime? observedTimestamp,
    Map<String, AttributeValue> attributes = const {},
    this.spanContext,
  })  : severity = severity ?? LogRecordSeverity.info,
        timestamp = (timestamp ?? DateTime.now().toUtc()),
        observedTimestamp = (observedTimestamp ?? DateTime.now().toUtc()),
        attributes = Attributes(attributes);

  final String body;
  final LogRecordSeverity severity;
  final String? severityText;
  final DateTime timestamp;
  final DateTime observedTimestamp;
  final Attributes attributes;
  final SpanContext? spanContext;
}
