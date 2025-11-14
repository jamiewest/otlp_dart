import 'dart:io';

class EnvironmentReader {
  const EnvironmentReader();

  String? operator [](String key) => Platform.environment[key];

  Map<String, String> get entries => Platform.environment;
}

EnvironmentReader createEnvironmentReader() => const EnvironmentReader();
