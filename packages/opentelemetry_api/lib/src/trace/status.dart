/// Status reported by a span.
class Status {
  const Status(this.statusCode, [this.description]);

  static const Status unset = Status(StatusCode.unset);
  static const Status ok = Status(StatusCode.ok);

  final StatusCode statusCode;
  final String? description;
}

enum StatusCode { unset, ok, error }
