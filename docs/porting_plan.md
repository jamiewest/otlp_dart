# Porting Plan

This repository re-implements the OpenTelemetry .NET components in Dart while
keeping the overall naming and layering model:

- `OpenTelemetry.Api` → `packages/opentelemetry_api`
  - Contracts for Tracing (Span, SpanContext, SpanKind, Status, Event, Link),
    logs (Logger, LogRecord, severity), and metrics (Meter, instruments).
  - Context propagation helpers, attributes, baggage, propagator interfaces.
  - No SDK/runtime specific behavior. Works on VM & web (no dart:io).
- `OpenTelemetry` (SDK) → `packages/opentelemetry_sdk`
  - Implements the API contracts plus processors, samplers, Resource, and
    instrumentation scope/identity abstractions.
  - Provides builders for tracer, logger, and meter providers mirroring the
    .NET builder patterns (with simple processors + exporters).
- `OpenTelemetry.Exporter.Console` → `packages/opentelemetry_exporter_console`
  - Depends only on the API + SDK and outputs traces/metrics/logs to stdout /
    debugPrint.
- `OpenTelemetry.Exporter.OpenTelemetryProtocol` →
  `packages/opentelemetry_exporter_otlp`
  - Uses OTLP/HTTP+JSON payloads for traces, metrics, and logs.
  - Mirrors .NET defaults for headers/environment overrides.
- `Shared` → `packages/opentelemetry_shared`
  - Contains utilities reused by SDK/exporters (environment variable helpers,
    resource detectors, exponential retry policy, attribute validation).

## Layering Targets

```
opentelemetry_exporter_console ┐
opentelemetry_exporter_otlp     ├─> opentelemetry_sdk
opentelemetry_sdk ─────────────┘         │
                                         └─> opentelemetry_api
shared utilities ──────────────────────────────────────────────┘
```

Every library exposes a `library` entrypoint mirroring the .NET namespace:

- `package:opentelemetry_api/opentelemetry_api.dart` → `OpenTelemetry.Api.*`
- `package:opentelemetry_sdk/opentelemetry_sdk.dart` → `OpenTelemetry.*`
- Exporters re-export their builders via `OpenTelemetry.Exporter.*` naming.

## Deliverables for the initial drop

1. Implement Span/Tracer contracts, `Context`, baggage, propagators, metrics,
   and logs in the API package.
2. Provide SDK providers (trace/logs/metrics) with processors, samplers, meter
   readers, and default resource.
3. Console exporter writing structured traces/metrics/logs.
4. OTLP exporter using HTTP/JSON as a starting point for all signals.
5. Shared package with environment configuration + retry/backoff helpers.
6. Integration tests/examples to exercise recording data + exporting.

## Runtime targets

- The API layer only uses `dart:collection`, `dart:convert`, `dart:async`, and
  `dart:typed_data`, making it web safe.
- SDK/exporters gate `dart:io` usage behind conditional imports so the
  libraries continue to load on the web (Console exporter will no-op).
