import 'dart:math';

class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 5,
    this.initialBackoff = const Duration(milliseconds: 500),
    this.maxBackoff = const Duration(seconds: 5),
    this.backoffMultiplier = 1.5,
    this.jitterFactor = 0.2,
  });

  final int maxAttempts;
  final Duration initialBackoff;
  final Duration maxBackoff;
  final double backoffMultiplier;
  final double jitterFactor;

  static final Random _random = Random();

  Duration backoffForAttempt(int attempt) {
    if (attempt <= 1) {
      return _applyJitter(initialBackoff);
    }
    var millis = initialBackoff.inMilliseconds.toDouble();
    for (var i = 1; i < attempt; i++) {
      millis *= backoffMultiplier;
      if (millis >= maxBackoff.inMilliseconds) {
        millis = maxBackoff.inMilliseconds.toDouble();
        break;
      }
    }
    return _applyJitter(Duration(milliseconds: millis.round()));
  }

  Duration _applyJitter(Duration input) {
    final millis = input.inMilliseconds;
    final delta = (millis * jitterFactor);
    final jitter = (_random.nextDouble() * 2 - 1) * delta;
    final value = (millis + jitter).clamp(0, maxBackoff.inMilliseconds).round();
    return Duration(milliseconds: value);
  }

  Future<T> execute<T>(Future<T> Function(int attempt) operation,
      {bool Function(Object error)? shouldRetry}) async {
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await operation(attempt);
      } catch (error) {
        lastError = error;
        final canRetry = shouldRetry?.call(error) ?? true;
        if (!canRetry || attempt == maxAttempts) {
          rethrow;
        }
        await Future<void>.delayed(backoffForAttempt(attempt));
      }
    }
    throw lastError ?? StateError('RetryPolicy.execute failed without error');
  }
}
