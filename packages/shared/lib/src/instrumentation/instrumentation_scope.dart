class InstrumentationScope {
  const InstrumentationScope(this.name, {this.version, this.schemaUrl});

  final String name;
  final String? version;
  final String? schemaUrl;

  @override
  bool operator ==(Object other) =>
      other is InstrumentationScope &&
      other.name == name &&
      other.version == version &&
      other.schemaUrl == schemaUrl;

  @override
  int get hashCode => Object.hash(name, version, schemaUrl);
}
