class EnvironmentReader {
  const EnvironmentReader();

  String? operator [](String key) => null;

  Map<String, String> get entries => const {};
}

EnvironmentReader createEnvironmentReader() => const EnvironmentReader();
