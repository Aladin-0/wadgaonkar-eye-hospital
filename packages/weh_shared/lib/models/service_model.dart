/// Clinical Hospital Service data model (e.g. Cataract, LASIK, Glaucoma evaluation)
/// Supports Firestore and Django REST Framework JSON mapping.
class HospitalService {
  final String id;
  final String title;
  final String department;
  final String description;
  final double baseFee;
  final int? durationMinutesOverride;
  final String iconCode;
  final bool isActive;
  final List<String>? preparationInstructions;

  const HospitalService({
    required this.id,
    required this.title,
    required this.department,
    required this.description,
    required this.baseFee,
    this.durationMinutesOverride,
    this.iconCode = 'visibility',
    this.isActive = true,
    this.preparationInstructions,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'department': department,
      'description': description,
      'baseFee': baseFee,
      'durationMinutesOverride': durationMinutesOverride,
      'iconCode': iconCode,
      'isActive': isActive,
      'preparationInstructions': preparationInstructions,
    };
  }

  Map<String, dynamic> toDjangoJson() {
    return {
      'id': id,
      'title': title,
      'department': department,
      'description': description,
      'base_fee': baseFee,
      'duration_minutes_override': durationMinutesOverride,
      'icon_code': iconCode,
      'is_active': isActive,
      'preparation_instructions': preparationInstructions,
    };
  }

  factory HospitalService.fromMap(Map<String, dynamic> map) {
    return HospitalService(
      id: (map['id'] ?? map['service_id'] ?? '') as String,
      title: (map['title'] ?? map['name'] ?? map['service_name'] ?? '') as String,
      department: (map['department'] ?? map['category'] ?? '') as String,
      description: (map['description'] ?? '') as String,
      baseFee: _parseDouble(map['baseFee'] ?? map['base_fee'] ?? map['fee']),
      durationMinutesOverride: (map['durationMinutesOverride'] ?? map['duration_minutes_override']) as int?,
      iconCode: (map['iconCode'] ?? map['icon_code'] ?? 'visibility') as String,
      isActive: (map['isActive'] ?? map['is_active'] ?? true) as bool,
      preparationInstructions: (map['preparationInstructions'] ?? map['preparation_instructions']) != null
          ? List<String>.from(map['preparationInstructions'] ?? map['preparation_instructions'])
          : null,
    );
  }

  factory HospitalService.fromDjangoJson(Map<String, dynamic> json) =>
      HospitalService.fromMap(json);
  factory HospitalService.fromJson(Map<String, dynamic> json) =>
      HospitalService.fromMap(json);
  Map<String, dynamic> toJson() => toDjangoJson();

  static double _parseDouble(dynamic val) {
    if (val is double) return val;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  @override
  String toString() => 'HospitalService($title, Fee: ₹$baseFee)';
}
