import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:shared/shared.dart';

class Resource {
  Resource([Map<String, AttributeValue> attributes = const {}])
      : attributes = Attributes(attributes);

  final Attributes attributes;

  static Resource defaultResource() {
    final serviceName = Environment.getString('OTEL_SERVICE_NAME') ??
        Environment.getString('SERVICE_NAME') ??
        'unknown_service:dart';
    return Resource({'service.name': serviceName});
  }

  Resource merge(Resource other) {
    final merged = Map<String, AttributeValue>.from(attributes.toMap());
    merged.addAll(other.attributes.toMap());
    return Resource(merged);
  }

  Map<String, AttributeValue> toMap() => attributes.toMap();
}
