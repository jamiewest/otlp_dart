import 'console_writer_base.dart';

class _ConsoleWriterStub implements ConsoleWriter {
  @override
  void write(String message) {
    // ignore: avoid_print
    print(message);
  }
}

ConsoleWriter createConsoleWriter() => _ConsoleWriterStub();
