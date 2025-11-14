import 'console_writer_base.dart';
import 'console_writer_stub.dart'
    if (dart.library.io) 'console_writer_io.dart' as impl;

class ConsoleWriterHolder {
  ConsoleWriterHolder._();

  static final ConsoleWriter instance = impl.createConsoleWriter();
}
