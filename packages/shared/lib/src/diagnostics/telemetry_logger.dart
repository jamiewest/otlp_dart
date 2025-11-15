/// Internal diagnostic logging for OpenTelemetry SDK components.
///
/// This logger is used for internal SDK diagnostics and should not be
/// confused with the OpenTelemetry Logs API for application logging.
abstract class TelemetryLogger {
  /// Logs an error message with optional error object and stack trace.
  void error(String message, [Object? error, StackTrace? stackTrace]);

  /// Logs a warning message.
  void warning(String message);

  /// Logs a debug message.
  void debug(String message);

  /// Logs an info message.
  void info(String message);
}

/// A no-op implementation of [TelemetryLogger] that discards all log messages.
class NoOpTelemetryLogger implements TelemetryLogger {
  const NoOpTelemetryLogger();

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {}

  @override
  void warning(String message) {}

  @override
  void debug(String message) {}

  @override
  void info(String message) {}
}

/// A simple console-based implementation of [TelemetryLogger].
///
/// This logger prints messages to stderr for errors and warnings,
/// and to stdout for info and debug messages.
class ConsoleTelemetryLogger implements TelemetryLogger {
  const ConsoleTelemetryLogger({this.logLevel = LogLevel.warning});

  final LogLevel logLevel;

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (logLevel.index >= LogLevel.error.index) {
      print('[OTEL ERROR] $message');
      if (error != null) {
        print('[OTEL ERROR] Error: $error');
      }
      if (stackTrace != null) {
        print('[OTEL ERROR] Stack trace: $stackTrace');
      }
    }
  }

  @override
  void warning(String message) {
    if (logLevel.index >= LogLevel.warning.index) {
      print('[OTEL WARNING] $message');
    }
  }

  @override
  void debug(String message) {
    if (logLevel.index >= LogLevel.debug.index) {
      print('[OTEL DEBUG] $message');
    }
  }

  @override
  void info(String message) {
    if (logLevel.index >= LogLevel.info.index) {
      print('[OTEL INFO] $message');
    }
  }
}

/// Log levels for the telemetry logger.
enum LogLevel {
  /// No logging.
  none(0),

  /// Only error messages.
  error(1),

  /// Error and warning messages.
  warning(2),

  /// Error, warning, and info messages.
  info(3),

  /// All messages including debug.
  debug(4);

  const LogLevel(this.index);

  final int index;
}
