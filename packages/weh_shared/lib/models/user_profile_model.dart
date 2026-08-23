/// Patient Profile data model designed for seamless interoperability with
/// Django REST Framework, Firebase Firestore, FastAPI, and PostgreSQL backends.
class UserProfile {
  final String uid;
  final String patientId;
  final String fullName;
  final String mobileNumber;
  final int age;
  final String? gender;
  final String? bloodGroup;
  final String? email;
  final String? photoUrl;
  final String? address;
  final String? city;
  final String? pincode;
  final String? emergencyContact;
  final bool isProfileComplete;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.uid,
    required this.patientId,
    required this.fullName,
    required this.mobileNumber,
    required this.age,
    this.gender,
    this.bloodGroup,
    this.email,
    this.photoUrl,
    this.address,
    this.city,
    this.pincode,
    this.emergencyContact,
    this.isProfileComplete = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Factory helper for a newly registered patient
  factory UserProfile.create({
    required String uid,
    required String fullName,
    required String mobileNumber,
    required int age,
    String? gender,
    String? bloodGroup,
    String? email,
    String? photoUrl,
    String? address,
    String? city,
    String? pincode,
    String? emergencyContact,
  }) {
    final now = DateTime.now();
    // Generate clean hospital patient ID from last 4 characters of UID
    final cleanUid = uid.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final suffix = cleanUid.length >= 4
        ? cleanUid.substring(cleanUid.length - 4).toUpperCase()
        : '0001';
    final patientId = 'WEH-${now.year}-$suffix';

    return UserProfile(
      uid: uid,
      patientId: patientId,
      fullName: fullName.trim(),
      mobileNumber: mobileNumber.trim(),
      age: age,
      gender: gender?.trim(),
      bloodGroup: bloodGroup?.trim(),
      email: email?.trim(),
      photoUrl: photoUrl,
      address: address?.trim(),
      city: city?.trim() ?? 'Ahmednagar',
      pincode: pincode?.trim(),
      emergencyContact: emergencyContact?.trim(),
      isProfileComplete: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Initial or empty template
  factory UserProfile.empty(
    String uid, {
    String? email,
    String? displayName,
    String? photoUrl,
  }) {
    return UserProfile(
      uid: uid,
      patientId: '',
      fullName: displayName ?? '',
      mobileNumber: '',
      age: 0,
      gender: null,
      bloodGroup: null,
      email: email,
      photoUrl: photoUrl,
      address: null,
      city: 'Ahmednagar',
      pincode: null,
      emergencyContact: null,
      isProfileComplete: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Standard Map serialization (supports both Firestore and General REST)
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'patientId': patientId,
      'fullName': fullName,
      'mobileNumber': mobileNumber,
      'age': age,
      'gender': gender,
      'bloodGroup': bloodGroup,
      'email': email,
      'photoUrl': photoUrl,
      'address': address,
      'city': city,
      'pincode': pincode,
      'emergencyContact': emergencyContact,
      'isProfileComplete': isProfileComplete,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Django REST Framework / PostgreSQL snake_case serialization
  /// Matches standard `class PatientSerializer(serializers.ModelSerializer)`
  Map<String, dynamic> toDjangoJson() {
    return {
      'uid': uid,
      'patient_id': patientId,
      'full_name': fullName,
      'mobile_number': mobileNumber,
      'age': age,
      'gender': gender,
      'blood_group': bloodGroup,
      'email': email,
      'photo_url': photoUrl,
      'address': address,
      'city': city,
      'pincode': pincode,
      'emergency_contact': emergencyContact,
      'is_profile_complete': isProfileComplete,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Alias for JSON encoding
  Map<String, dynamic> toJson() => toDjangoJson();

  /// Robust deserializer accepting both camelCase (Firestore) and snake_case (Django DRF / FastAPI)
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: (map['uid'] ?? map['user_id'] ?? map['auth_uid'] ?? '') as String,
      patientId:
          (map['patientId'] ?? map['patient_id'] ?? map['id'] ?? '') as String,
      fullName: (map['fullName'] ??
          map['full_name'] ??
          map['name'] ??
          map['patient_name'] ??
          '') as String,
      mobileNumber: (map['mobileNumber'] ??
          map['mobile_number'] ??
          map['phone'] ??
          map['phone_number'] ??
          '') as String,
      age: _parseAge(map['age']),
      gender: (map['gender'] ?? map['sex']) as String?,
      bloodGroup: (map['bloodGroup'] ?? map['blood_group']) as String?,
      email: map['email'] as String?,
      photoUrl:
          (map['photoUrl'] ?? map['photo_url'] ?? map['avatar_url']) as String?,
      address: map['address'] as String?,
      city: (map['city'] ?? map['district']) as String? ?? 'Ahmednagar',
      pincode: (map['pincode'] ?? map['postal_code'] ?? map['zip']) as String?,
      emergencyContact: (map['emergencyContact'] ??
          map['emergency_contact'] ??
          map['emergency_phone']) as String?,
      isProfileComplete: (map['isProfileComplete'] ??
          map['is_profile_complete'] ??
          false) as bool,
      createdAt: _parseDate(map['createdAt'] ?? map['created_at']),
      updatedAt: _parseDate(map['updatedAt'] ?? map['updated_at']),
    );
  }

  /// Factory for Django REST API response
  factory UserProfile.fromDjangoJson(Map<String, dynamic> json) =>
      UserProfile.fromMap(json);

  /// Factory for standard JSON map
  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      UserProfile.fromMap(json);

  UserProfile copyWith({
    String? uid,
    String? patientId,
    String? fullName,
    String? mobileNumber,
    int? age,
    String? gender,
    String? bloodGroup,
    String? email,
    String? photoUrl,
    String? address,
    String? city,
    String? pincode,
    String? emergencyContact,
    bool? isProfileComplete,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      patientId: patientId ?? this.patientId,
      fullName: fullName ?? this.fullName,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      address: address ?? this.address,
      city: city ?? this.city,
      pincode: pincode ?? this.pincode,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Formatted display mobile (e.g. +91 98220 12345)
  String get formattedMobile {
    final clean = mobileNumber.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 10) {
      return '+91 ${clean.substring(0, 5)} ${clean.substring(5)}';
    }
    return mobileNumber;
  }

  /// Initial letter for avatar
  String get initials {
    if (fullName.trim().isEmpty) return 'WE';
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length > 1 && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : 'WE';
  }

  static int _parseAge(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  @override
  String toString() =>
      'UserProfile(patientId: $patientId, uid: $uid, name: $fullName, mobile: $mobileNumber, age: $age)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile &&
        other.uid == uid &&
        other.patientId == patientId &&
        other.fullName == fullName &&
        other.mobileNumber == mobileNumber &&
        other.age == age &&
        other.gender == gender &&
        other.bloodGroup == bloodGroup &&
        other.email == email &&
        other.isProfileComplete == isProfileComplete;
  }

  @override
  int get hashCode =>
      uid.hashCode ^
      patientId.hashCode ^
      fullName.hashCode ^
      mobileNumber.hashCode ^
      age.hashCode;
}
