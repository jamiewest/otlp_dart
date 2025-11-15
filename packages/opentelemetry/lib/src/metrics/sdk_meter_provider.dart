import 'dart:async';

import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:shared/shared.dart';

import '../resource/resource.dart';
import 'metric_data.dart';
import 'metric_exporter.dart';
import 'metric_pipeline_config.dart';
import 'metric_storage.dart';
import 'sdk_meter.dart';

class SdkMeterProvider implements MeterProvider {
  SdkMeterProvider({
    required this.resource,
    required List<MetricPipelineConfig> pipelineConfigs,
    List<double>? histogramBoundaries,
  }) : histogramBoundaries =
            List<double>.unmodifiable(histogramBoundaries ?? _defaultHistogramBoundaries) {
    for (final config in pipelineConfigs) {
      final pipeline = _MetricPipeline(config.exporter, config.exportInterval);
      _pipelines.add(pipeline);
      pipeline.start(this);
    }
  }

  final Resource resource;
  final List<double> histogramBoundaries;
  final Map<InstrumentationScope, SdkMeter> _meters = {};
  final List<_MetricRegistration> _registrations = [];
  final List<_MetricPipeline> _pipelines = [];
  bool _isShutdown = false;

  static const List<double> _defaultHistogramBoundaries = <double>[
    0,
    5,
    10,
    25,
    50,
    75,
    100,
    250,
    500,
    1_000,
  ];

  @override
  Meter getMeter(String name, {String? version, String? schemaUrl}) {
    final scope =
        InstrumentationScope(name, version: version, schemaUrl: schemaUrl);
    return _meters.putIfAbsent(
      scope,
      () => SdkMeter(_registerStorage, scope, histogramBoundaries),
    );
  }

  void _registerStorage(MetricStorage storage, InstrumentationScope scope) {
    _registrations.add(_MetricRegistration(storage, scope));
  }

  List<MetricData> _collect() {
    final metrics = <MetricData>[];
    for (final registration in _registrations) {
      final data = registration.storage
          .collect(() => resource, registration.instrumentationScope);
      if (data != null && !data.isEmpty) {
        metrics.add(data);
      }
    }
    return metrics;
  }

  Future<void> _export(MetricExporter exporter) async {
    if (_isShutdown) {
      return;
    }
    final data = _collect();
    if (data.isEmpty) {
      return;
    }
    await exporter.export(data);
  }

  @override
  Future<void> forceFlush() async {
    final futures = <Future<void>>[];
    for (final pipeline in _pipelines) {
      futures.add(pipeline.exportNow());
    }
    await Future.wait(futures);
    for (final pipeline in _pipelines) {
      await pipeline.forceFlush();
    }
  }

  @override
  Future<void> shutdown() async {
    if (_isShutdown) {
      return;
    }
    _isShutdown = true;
    for (final pipeline in _pipelines) {
      await pipeline.shutdown();
    }
  }
}

class _MetricRegistration {
  _MetricRegistration(this.storage, this.instrumentationScope);

  final MetricStorage storage;
  final InstrumentationScope instrumentationScope;
}

class _MetricPipeline {
  _MetricPipeline(this.exporter, this.interval);

  final MetricExporter exporter;
  final Duration? interval;
  Timer? _timer;
  SdkMeterProvider? _provider;

  void start(SdkMeterProvider provider) {
    _provider = provider;
    final currentInterval = interval;
    if (currentInterval != null) {
      _timer = Timer.periodic(currentInterval, (_) {
        provider._export(exporter);
      });
    }
  }

  Future<void> exportNow() {
    final provider = _provider;
    if (provider == null) {
      return Future.value();
    }
    return provider._export(exporter);
  }

  Future<void> shutdown() async {
    _timer?.cancel();
    await exporter.shutdown();
  }

  Future<void> forceFlush() => exporter.forceFlush();
}
