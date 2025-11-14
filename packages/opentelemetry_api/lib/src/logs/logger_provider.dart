import 'logger.dart';

abstract class LoggerProvider {
  Logger getLogger(String name, {String? version, String? schemaUrl});

  Future<void> forceFlush() async {}

  Future<void> shutdown() async {}
}

class NoopLoggerProvider implements LoggerProvider {
  const NoopLoggerProvider();

  static const NoopLoggerProvider instance = NoopLoggerProvider();

  @override
  Logger getLogger(String name, {String? version, String? schemaUrl}) =>
      const NoopLogger();

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {}
}
