import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:test/test.dart';

void main() {
  group('TraceFlags', () {
    test('none has value 0', () {
      expect(TraceFlags.none.value, equals(0));
      expect(TraceFlags.none.isSampled, isFalse);
    });

    test('sampled has value 1', () {
      expect(TraceFlags.sampled.value, equals(1));
      expect(TraceFlags.sampled.isSampled, isTrue);
    });

    test('fromByte masks to 8 bits', () {
      expect(TraceFlags.fromByte(0xFF).value, equals(0xFF));
      expect(TraceFlags.fromByte(0x1FF).value, equals(0xFF));
      expect(TraceFlags.fromByte(0x101).value, equals(0x01));
    });

    test('isSampled checks LSB', () {
      expect(TraceFlags.fromByte(0x00).isSampled, isFalse);
      expect(TraceFlags.fromByte(0x01).isSampled, isTrue);
      expect(TraceFlags.fromByte(0x02).isSampled, isFalse);
      expect(TraceFlags.fromByte(0x03).isSampled, isTrue);
      expect(TraceFlags.fromByte(0xFF).isSampled, isTrue);
      expect(TraceFlags.fromByte(0xFE).isSampled, isFalse);
    });
  });
}
