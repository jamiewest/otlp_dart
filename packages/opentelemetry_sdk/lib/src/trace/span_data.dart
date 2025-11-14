import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:opentelemetry_shared/opentelemetry_shared.dart';

import '../resource/resource.dart';

class SpanData {
  SpanData({
    required this.context,
    required this.parentSpanContext,
    required this.resource,
    required this.instrumentationScope,
    required this.name,
    required this.kind,
    required this.status,
    required this.startTime,
    required this.endTime,
    required this.attributes,
    required this.events,
    required this.links,
    required this.totalRecordedEvents,
    required this.totalRecordedLinks,
    required this.totalAttributeCount,
  });

  final SpanContext context;
  final SpanContext? parentSpanContext;
  final Resource resource;
  final InstrumentationScope instrumentationScope;
  final String name;
  final SpanKind kind;
  final Status status;
  final DateTime startTime;
  final DateTime endTime;
  final Attributes attributes;
  final List<SpanEvent> events;
  final List<Link> links;
  final int totalRecordedEvents;
  final int totalRecordedLinks;
  final int totalAttributeCount;
}
