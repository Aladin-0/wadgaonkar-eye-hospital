import 'package:weh_shared/weh_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Models Unit Tests', () {
    test('AuthUser serialization & copyWith', () {
      const user = AuthUser(
        uid: 'user_123',
        email: 'test@example.com',
        displayName: 'Aarav Patil',
        photoUrl: 'https://example.com/photo.png',
        isEmailVerified: true,
      );

      final map = user.toMap();
      expect(map['uid'], 'user_123');
      expect(map['email'], 'test@example.com');
      expect(map['displayName'], 'Aarav Patil');

      final fromMap = AuthUser.fromMap(map);
      expect(fromMap, equals(user));

      final updated = user.copyWith(displayName: 'Aarav R. Patil');
      expect(updated.displayName, 'Aarav R. Patil');
      expect(updated.uid, 'user_123');
    });

    test('UserProfile creation, serialization, formatting & initials', () {
      final profile = UserProfile.create(
        uid: 'user_xyz_9876',
        fullName: 'Sunita Sharma',
        mobileNumber: '9822012345',
        age: 52,
        gender: 'Female',
        bloodGroup: 'B+',
        email: 'sunita@gmail.com',
        address: '12 Shivaji Road',
        city: 'Ahmednagar',
      );

      expect(profile.fullName, 'Sunita Sharma');
      expect(profile.initials, 'SS');
      expect(profile.formattedMobile, '+91 98220 12345');
      expect(profile.gender, 'Female');
      expect(profile.bloodGroup, 'B+');
      expect(profile.city, 'Ahmednagar');
      expect(profile.isProfileComplete, isTrue);
      expect(profile.patientId, contains('WEH-'));

      final map = profile.toMap();
      expect(map['fullName'], 'Sunita Sharma');
      expect(map['mobileNumber'], '9822012345');
      expect(map['age'], 52);

      final fromMap = UserProfile.fromMap(map);
      expect(fromMap.uid, profile.uid);
      expect(fromMap.fullName, profile.fullName);
      expect(fromMap.mobileNumber, profile.mobileNumber);
      expect(fromMap.age, 52);
    });

    test('UserProfile Django REST Framework snake_case interoperability', () {
      // Simulating a response payload directly from Django REST Framework / PostgreSQL
      final djangoApiResponse = {
        'uid': 'django_user_8899',
        'patient_id': 'WEH-2026-8899',
        'full_name': 'Dr. Rajesh Patil',
        'mobile_number': '9822199887',
        'age': '48', // String age from form/serializer
        'gender': 'Male',
        'blood_group': 'O+',
        'email': 'rajesh.patil@hospital.in',
        'photo_url': 'https://example.com/avatar.jpg',
        'address': 'MG Road, Savedi',
        'city': 'Ahmednagar',
        'pincode': '414003',
        'emergency_contact': '9822011223',
        'is_profile_complete': true,
        'created_at': '2026-08-05T12:00:00.000Z',
        'updated_at': '2026-08-05T12:00:00.000Z',
      };

      final profile = UserProfile.fromDjangoJson(djangoApiResponse);
      expect(profile.uid, 'django_user_8899');
      expect(profile.patientId, 'WEH-2026-8899');
      expect(profile.fullName, 'Dr. Rajesh Patil');
      expect(profile.mobileNumber, '9822199887');
      expect(profile.age, 48);
      expect(profile.gender, 'Male');
      expect(profile.bloodGroup, 'O+');
      expect(profile.city, 'Ahmednagar');
      expect(profile.pincode, '414003');
      expect(profile.emergencyContact, '9822011223');
      expect(profile.isProfileComplete, isTrue);

      // Verify serialization back to Django snake_case JSON format
      final serializedDjango = profile.toDjangoJson();
      expect(serializedDjango['patient_id'], 'WEH-2026-8899');
      expect(serializedDjango['full_name'], 'Dr. Rajesh Patil');
      expect(serializedDjango['mobile_number'], '9822199887');
      expect(serializedDjango['blood_group'], 'O+');
      expect(serializedDjango['emergency_contact'], '9822011223');
    });
  });
}
