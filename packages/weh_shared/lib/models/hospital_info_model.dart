import 'package:flutter/material.dart';

/// Hospital milestone achievement model
class HospitalMilestone {
  final String title;
  final String count;
  final String subtitle;
  final IconData icon;

  const HospitalMilestone({
    required this.title,
    required this.count,
    required this.subtitle,
    required this.icon,
  });
}

/// Ophthalmology Department / Speciality model
class EyeDepartment {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final String tag;
  final Color accentColor;

  const EyeDepartment({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.tag,
    required this.accentColor,
  });
}

/// Key hospital facility model
class HospitalFacility {
  final String name;
  final String description;
  final IconData icon;

  const HospitalFacility({
    required this.name,
    required this.description,
    required this.icon,
  });
}

/// Static repository of authentic hospital details for Wadgaonkar Eye Hospital
class HospitalData {
  HospitalData._();

  static const List<HospitalMilestone> milestones = [
    HospitalMilestone(
      title: 'Trusted Experience',
      count: '32+',
      subtitle: 'Years of Dedicated Care',
      icon: Icons.verified_user_rounded,
    ),
    HospitalMilestone(
      title: 'Successful Surgeries',
      count: '40,000+',
      subtitle: 'Cataract & Laser Procedures',
      icon: Icons.visibility_rounded,
    ),
    HospitalMilestone(
      title: 'Happy Patients',
      count: '1,50,000+',
      subtitle: 'OPD Patients Treated',
      icon: Icons.favorite_rounded,
    ),
    HospitalMilestone(
      title: 'Patient Trust',
      count: '99.2%',
      subtitle: 'Satisfaction Rating',
      icon: Icons.star_rounded,
    ),
  ];

  static const List<EyeDepartment> departments = [
    EyeDepartment(
      id: 'cataract',
      name: 'Micro-Incision Cataract (MICS)',
      description: 'Stitchless phacoemulsification with premium multifocal and toric lens implants.',
      icon: Icons.remove_red_eye_rounded,
      tag: 'Most Performed',
      accentColor: Color(0xFF0A6847),
    ),
    EyeDepartment(
      id: 'lasik',
      name: 'LASIK & Refractive Laser',
      description: 'Advanced blade-free laser vision correction for spectacle removal.',
      icon: Icons.auto_awesome_rounded,
      tag: 'Advanced Tech',
      accentColor: Color(0xFF0E8388),
    ),
    EyeDepartment(
      id: 'glaucoma',
      name: 'Glaucoma & Pressure Care',
      description: 'Early detection, laser trabeculoplasty, and surgical intraocular pressure control.',
      icon: Icons.health_and_safety_rounded,
      tag: 'Vision Saving',
      accentColor: Color(0xFF0F2C59),
    ),
    EyeDepartment(
      id: 'retina',
      name: 'Retina & Diabetic Eye Clinic',
      description: 'Expert management of diabetic retinopathy, macular degeneration, and retinal lasers.',
      icon: Icons.biotech_rounded,
      tag: 'Specialized',
      accentColor: Color(0xFF139669),
    ),
    EyeDepartment(
      id: 'pediatric',
      name: 'Pediatric Ophthalmology & Squint',
      description: 'Gentle child eye examinations, lazy eye (amblyopia) therapy, and squint correction.',
      icon: Icons.child_care_rounded,
      tag: 'Child Care',
      accentColor: Color(0xFF2563EB),
    ),
    EyeDepartment(
      id: 'cornea',
      name: 'Cornea & Dry Eye Centre',
      description: 'Comprehensive corneal treatments, collagen cross-linking (C3R), and tear-film therapy.',
      icon: Icons.water_drop_rounded,
      tag: 'Clinical Care',
      accentColor: Color(0xFF7C3AED),
    ),
  ];

  static const List<HospitalFacility> facilities = [
    HospitalFacility(
      name: 'Ultra-Clean Modular Laser OT',
      description: 'HEPA filtered laminar airflow sterile surgical suites.',
      icon: Icons.sanitizer_rounded,
    ),
    HospitalFacility(
      name: 'High-Resolution 3D OCT Imaging',
      description: 'Micron-level retinal and optic nerve head scans.',
      icon: Icons.camera_enhance_rounded,
    ),
    HospitalFacility(
      name: 'Automated Visual Field Analyser',
      description: 'Gold-standard perimetry for glaucoma monitoring.',
      icon: Icons.grid_view_rounded,
    ),
    HospitalFacility(
      name: 'In-House Optical & Pharmacy',
      description: 'Original ophthalmology medications and custom lenses.',
      icon: Icons.local_pharmacy_rounded,
    ),
  ];
}
