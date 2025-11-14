# OTLP Dart (OpenTelemetry for Dart)

A multi-package workspace that ports the core OpenTelemetry .NET components to
Dart. The goal is API parity with `OpenTelemetry.Api`, the `OpenTelemetry`
SDK, and the console/OTLP exporters while keeping Dart-friendly ergonomics.

## Packages

| Package | Description |
| --- | --- |
| `opentelemetry_api` | Contracts for tracing/baggage/context propagation. |
| `opentelemetry_sdk` | SDK implementation with tracing, metrics, and logs. |
| `opentelemetry_shared` | Utilities shared by sdk/exporters (resources, env). |
| `opentelemetry_exporter_console` | Writes traces/metrics/logs to stdout / debug console. |
| `opentelemetry_exporter_otlp` | OTLP/HTTP exporter for traces, metrics, and logs. |

Each package mirrors the namespaces from the .NET implementation so existing
OpenTelemetry documentation ports cleanly.

## Development

Each directory under `packages/` is a standalone Dart package. Run `dart pub get`
inside whichever package you are working on. Basic usage examples live under
`examples/`:

- `basic_tracing.dart` wires the SDK span pipeline to the console exporter.
- `logs_metrics_example.dart` wires the logger + meter providers to console exporters.

All code runs on both the Dart VM and the web (through `dart compile js`).
