import 'dart:io';

import 'console_writer_base.dart';

class _ConsoleWriterIo implements ConsoleWriter {
  @override
  void write(String message) {
    stdout.writeln(message);
  }
}

ConsoleWriter createConsoleWriter() => _ConsoleWriterIo();
