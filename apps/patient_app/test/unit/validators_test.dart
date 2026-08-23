import 'package:flutter_test/flutter_test.dart';
import 'package:wadgaonkar_eye_hospital/core/utils/validators.dart';

void main() {
  group('Validators Tests', () {
    test('Full Name validation', () {
      expect(Validators.validateFullName(null), isNotNull);
      expect(Validators.validateFullName(''), isNotNull);
      expect(Validators.validateFullName('A'), isNotNull);
      expect(Validators.validateFullName('Dr. Rajesh Patil'), isNull);
      expect(Validators.validateFullName('Aarav Deshmukh'), isNull);
    });

    test('Indian 10-Digit Mobile Number validation', () {
      expect(Validators.validateMobileNumber(null), isNotNull);
      expect(Validators.validateMobileNumber(''), isNotNull);
      expect(Validators.validateMobileNumber('12345'), isNotNull);
      expect(Validators.validateMobileNumber('5999999999'), isNotNull); // Doesn't start with 6,7,8,9
      expect(Validators.validateMobileNumber('9822012345'), isNull);
      expect(Validators.validateMobileNumber('+91 9822012345'), isNull);
      expect(Validators.validateMobileNumber('98220 12345'), isNull);
    });

    test('Patient Age validation', () {
      expect(Validators.validateAge(null), isNotNull);
      expect(Validators.validateAge(''), isNotNull);
      expect(Validators.validateAge('0'), isNotNull);
      expect(Validators.validateAge('125'), isNotNull);
      expect(Validators.validateAge('abc'), isNotNull);
      expect(Validators.validateAge('45'), isNull);
      expect(Validators.validateAge('8'), isNull);
      expect(Validators.validateAge('92'), isNull);
    });

    test('Clean Mobile Number utility', () {
      expect(Validators.cleanMobileNumber('+91 98220 12345'), '9822012345');
      expect(Validators.cleanMobileNumber('09822012345'), '9822012345');
      expect(Validators.cleanMobileNumber('98220-12345'), '9822012345');
    });
  });
}
