import 'package:opentelemetry_api/opentelemetry_api.dart';

enum SamplingDecision { drop, recordOnly, recordAndSample }

class SamplingResult {
  const SamplingResult(this.decision,
      {this.attributes = const <String, AttributeValue>{}, this.traceState});

  final SamplingDecision decision;
  final Map<String, AttributeValue> attributes;
  final TraceState? traceState;

  bool get isSampled => decision == SamplingDecision.recordAndSample;
}

class SamplingOptions {
  SamplingOptions({
    required this.parentContext,
    required this.traceId,
    required this.spanName,
    required this.spanKind,
    this.links = const <Link>[],
    Map<String, AttributeValue> attributes = const {},
  }) : attributes = Attributes(attributes);

  final Context parentContext;
  final TraceId traceId;
  final String spanName;
  final SpanKind spanKind;
  final List<Link> links;
  final Attributes attributes;
}

abstract class Sampler {
  SamplingResult shouldSample(SamplingOptions options);

  String get description;
}

class AlwaysOnSampler implements Sampler {
  const AlwaysOnSampler();

  @override
  String get description => 'AlwaysOnSampler';

  @override
  SamplingResult shouldSample(SamplingOptions options) =>
      const SamplingResult(SamplingDecision.recordAndSample);
}

class AlwaysOffSampler implements Sampler {
  const AlwaysOffSampler();

  @override
  String get description => 'AlwaysOffSampler';

  @override
  SamplingResult shouldSample(SamplingOptions options) =>
      const SamplingResult(SamplingDecision.drop);
}

class TraceIdRatioBasedSampler implements Sampler {
  TraceIdRatioBasedSampler(this.probability)
      : assert(probability >= 0 && probability <= 1);

  final double probability;
  static final BigInt _maxValue = (BigInt.one << 128) - BigInt.one;

  @override
  String get description => 'TraceIdRatioBasedSampler($probability)';

  @override
  SamplingResult shouldSample(SamplingOptions options) {
    if (probability <= 0) {
      return const SamplingResult(SamplingDecision.drop);
    }
    if (probability >= 1) {
      return const SamplingResult(SamplingDecision.recordAndSample);
    }
    final traceIdValue = BigInt.parse(options.traceId.value, radix: 16);
    final multiplier = (probability * 1000000).round();
    final threshold =
        (_maxValue * BigInt.from(multiplier)) ~/ BigInt.from(1000000);
    final sampled = traceIdValue <= threshold;
    return SamplingResult(
      sampled ? SamplingDecision.recordAndSample : SamplingDecision.drop,
    );
  }
}
