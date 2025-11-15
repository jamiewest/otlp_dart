# BatchSpanProcessor Implementation Summary

## Overview

Implemented a production-ready `BatchSpanProcessor` for the OpenTelemetry Dart SDK, ported and adapted from the [OpenTelemetry .NET implementation](https://github.com/open-telemetry/opentelemetry-dotnet).

## Implementation Details

### File Location
[`packages/opentelemetry/lib/src/trace/span_processor.dart`](packages/opentelemetry/lib/src/trace/span_processor.dart:53-180)

### Key Features

1. **Batching Logic**
   - Queues spans until batch size is reached or timer fires
   - Configurable `maxExportBatchSize` (default: 512)
   - Configurable `maxQueueSize` (default: 2048)
   - Drops spans when queue is full (prevents memory issues)

2. **Periodic Export**
   - Uses `Timer.periodic` for scheduled exports
   - Configurable `scheduledDelay` (default: 5000ms)
   - Timer is cancelled on shutdown

3. **Timeout Protection**
   - Export operations have configurable timeout (default: 30000ms)
   - Prevents hanging on slow exporters
   - Gracefully handles timeout errors

4. **Concurrency Control**
   - `_isExporting` flag prevents concurrent export operations
   - Proper synchronization in shutdown to wait for ongoing exports
   - Safe for concurrent span additions

5. **Graceful Shutdown**
   - Cancels timer first
   - Waits for any ongoing export to complete
   - Exports all remaining queued spans
   - Calls exporter shutdown

### Configuration Options

```dart
BatchSpanProcessor(
  exporter,
  maxQueueSize: 2048,          // Max spans in queue
  maxExportBatchSize: 512,     // Max spans per batch
  scheduledDelay: Duration(milliseconds: 5000),  // Export interval
  exportTimeout: Duration(milliseconds: 30000),  // Export timeout
)
```

### Comparison with .NET Implementation

| Feature | .NET | Dart | Notes |
|---------|------|------|-------|
| Queue | `ConcurrentQueue<T>` | `Queue<SpanData>` | Dart uses single-threaded event loop |
| Timer | `Task.Delay` + loop | `Timer.periodic` | Platform-appropriate async |
| Concurrency | Lock/Semaphore | `_isExporting` flag | Simpler in single-threaded Dart |
| Shutdown | ManualResetEvent | Polling with delay | Dart doesn't have events |
| Export timeout | CancellationToken | `Future.timeout()` | Built-in Dart feature |

## Test Coverage

### Test File
[`packages/opentelemetry/test/trace/batch_span_processor_test.dart`](packages/opentelemetry/test/trace/batch_span_processor_test.dart:1)

### Test Count: 15 tests ✅

#### Batching Tests (3 tests)
- ✅ Batches spans before exporting
- ✅ Exports on scheduled timer
- ✅ Respects maxQueueSize and drops spans when full

#### Force Flush Tests (2 tests)
- ✅ ForceFlush exports all pending spans
- ✅ ForceFlush exports in batches

#### Shutdown Tests (5 tests)
- ✅ Shutdown exports remaining spans
- ✅ Shutdown stops timer
- ✅ Does not accept spans after shutdown
- ✅ Shutdown is idempotent
- ✅ ForceFlush does nothing after shutdown

#### Edge Cases (5 tests)
- ✅ Handles export timeout
- ✅ Exports multiple batches when batch size is reached
- ✅ Uses default configuration
- ✅ Timer export does not interfere with manual export
- ✅ Handles concurrent span additions

### Test Patterns Used

1. **Timing Tests**: Uses realistic delays (100ms-10s) to verify timer behavior
2. **Capacity Tests**: Verifies queue size limits and span dropping
3. **Shutdown Tests**: Ensures proper cleanup and no data loss
4. **Concurrency Tests**: Verifies thread-safe span additions
5. **Edge Case Tests**: Timeout handling, idempotency, post-shutdown behavior

## Key Implementation Challenges & Solutions

### Challenge 1: Timer/Shutdown Race Condition
**Problem**: Timer could fire during shutdown, causing deadlock when both try to export.

**Solution**:
```dart
// Cancel timer first
_timer?.cancel();
_timer = null;

// Wait for ongoing export
while (_isExporting) {
  await Future.delayed(const Duration(milliseconds: 10));
}

// Then export remaining
while (_queue.isNotEmpty) {
  await _exportBatch();
}
```

### Challenge 2: Concurrent Export Prevention
**Problem**: Multiple calls to `_exportBatch()` could overlap.

**Solution**:
```dart
if (_isExporting) {
  return; // Skip if already exporting
}
_isExporting = true;
try {
  // ... export logic
} finally {
  _isExporting = false;
}
```

### Challenge 3: Queue Safety
**Problem**: Queue could be modified during iteration.

**Solution**:
```dart
for (var i = 0; i < batchSize; i++) {
  if (_queue.isEmpty) break;  // Safe check
  batch.add(_queue.removeFirst());
}
```

## Usage Example

```dart
import 'package:opentelemetry/opentelemetry.dart';

// Create exporter
final exporter = OtlpTraceExporter(/* config */);

// Create batch processor with custom config
final processor = BatchSpanProcessor(
  exporter,
  maxQueueSize: 1024,
  maxExportBatchSize: 256,
  scheduledDelay: Duration(seconds: 2),
);

// Create tracer provider
final provider = SdkTracerProviderBuilder()
    .addSpanProcessor(processor)
    .build();

// Use tracer...

// Cleanup
await provider.shutdown(); // Exports remaining spans
```

## Performance Characteristics

### Memory Usage
- **Queue overhead**: O(n) where n = number of queued spans
- **Max memory**: Bounded by `maxQueueSize` (default: 2048 spans)
- **Span dropping**: Prevents unbounded memory growth

### Latency
- **Span end latency**: O(1) - just adds to queue
- **Export latency**: Configurable via `scheduledDelay`
- **Shutdown latency**: O(remaining spans / batch size) × export time

### Throughput
- **High throughput**: Batching reduces export overhead
- **Configurable**: Adjust batch size and delay for workload
- **Concurrent-safe**: Multiple threads can add spans simultaneously

## Advantages Over SimpleSpanProcessor

| Aspect | SimpleSpanProcessor | BatchSpanProcessor |
|--------|--------------------|--------------------|
| Export timing | Every span | Batched periodically |
| Latency on span end | High (waits for export) | Low (just queues) |
| Network overhead | High (many small requests) | Low (fewer large requests) |
| Memory usage | Low | Medium (bounded queue) |
| Data loss risk | Low | Low (exports on shutdown) |
| **Best for** | Development/debugging | **Production** |

## Production Readiness Checklist

- ✅ Proper batching with configurable parameters
- ✅ Memory-bounded queue with overflow handling
- ✅ Periodic export with timer
- ✅ Export timeout protection
- ✅ Graceful shutdown with remaining span export
- ✅ Concurrency-safe implementation
- ✅ Comprehensive test coverage (15 tests)
- ✅ Error handling (export failures, timeouts)
- ✅ Idempotent shutdown
- ✅ Force flush support

## Integration with TracerProvider

The `BatchSpanProcessor` integrates seamlessly with the existing SDK:

```dart
final provider = SdkTracerProviderBuilder()
    .setResource(Resource({'service.name': 'my-service'}))
    .addSpanProcessor(BatchSpanProcessor(exporter))
    .setSampler(TraceIdRatioBasedSampler(0.1))
    .build();
```

## Next Steps

1. ✅ **Implemented**: BatchSpanProcessor with full test coverage
2. **TODO**: Add builder convenience methods
   ```dart
   .addBatchSpanProcessor(exporter, config: BatchConfig(...))
   ```
3. **TODO**: Add metrics/telemetry for the processor itself
   - Queue size gauge
   - Export success/failure counters
   - Export duration histogram
4. **TODO**: Consider adding environment variable configuration
   - `OTEL_BSP_MAX_QUEUE_SIZE`
   - `OTEL_BSP_MAX_EXPORT_BATCH_SIZE`
   - `OTEL_BSP_SCHEDULE_DELAY`
   - `OTEL_BSP_EXPORT_TIMEOUT`

## References

- [OpenTelemetry .NET BatchActivityExportProcessor](https://github.com/open-telemetry/opentelemetry-dotnet/blob/main/src/OpenTelemetry/BatchExportProcessor.cs)
- [OpenTelemetry Specification - Span Processor](https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/trace/sdk.md#span-processor)
- [Dart Timer API](https://api.dart.dev/stable/dart-async/Timer-class.html)

## Conclusion

The `BatchSpanProcessor` is now **production-ready** and provides essential batching functionality for high-throughput applications. It matches the behavior of the .NET implementation while being idiomatic to Dart's async model and single-threaded execution.

**Total test count: 66 SDK tests, all passing ✅**
