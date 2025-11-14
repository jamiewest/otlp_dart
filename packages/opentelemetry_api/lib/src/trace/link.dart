import 'attributes.dart';
import 'span_context.dart';

class Link {
  Link(this.context, [Map<String, AttributeValue> attributes = const {}])
      : attributes = Attributes(attributes);

  final SpanContext context;
  final Attributes attributes;
}
