# OTLP Dart (OpenTelemetry for Dart)

A multi-package workspace that ports the core OpenTelemetry .NET components to
Dart. The goal is API parity with `OpenTelemetry.Api`, the `OpenTelemetry`
SDK, and the console/OTLP exporters while keeping Dart-friendly ergonomics.

## Packages

| Package | Description |
| --- | --- |
| `opentelemetry_api` | Contracts for tracing/baggage/context propagation. |
| `opentelemetry` | SDK implementation with tracing, metrics, and logs. |
| `shared` | Utilities shared by sdk/exporters (resources, env). |
| `opentelemetry_exporter_console` | Writes traces/metrics/logs to stdout / debug console. |
| `opentelemetry_exporter_otlp` | OTLP exporter (gRPC or HTTP/Protobuf) for traces, metrics, and logs. |

Each package mirrors the namespaces from the .NET implementation so existing
OpenTelemetry documentation ports cleanly.

## Development

Each directory under `packages/` is a standalone Dart package. Run `dart pub get`
inside whichever package you are working on. Basic usage examples live under
`examples/`:

- `basic_tracing.dart` wires the SDK span pipeline to the console exporter.
- `logs_metrics_example.dart` wires the logger + meter providers to console exporters.

All code runs on both the Dart VM and the web (through `dart compile js`).

### OTLP transports

`opentelemetry_exporter_otlp` mirrors the .NET exporter defaults:

- gRPC over HTTP/2 is the default (compatible with .NET Aspire).
- Set `OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf` to force HTTP/Protobuf.
- Use the per-signal variables (`OTEL_EXPORTER_OTLP_TRACES_PROTOCOL`, etc.)
  and `OTEL_EXPORTER_OTLP_*_ENDPOINT` to mirror the .NET configuration keys.
- Custom headers respect `OTEL_EXPORTER_OTLP_HEADERS` (values may be
  URL-encoded, matching the .NET parsing rules).

When running on the web, the exporter automatically falls back to the HTTP
transport; on the Dart VM the gRPC pipeline uses HTTP/2 and supports retries
for the retryable gRPC status codes (`UNAVAILABLE`, `DEADLINE_EXCEEDED`,
`RESOURCE_EXHAUSTED`).
