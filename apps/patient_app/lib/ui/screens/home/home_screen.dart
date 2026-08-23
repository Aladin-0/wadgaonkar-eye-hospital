import 'package:weh_shared/weh_shared.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/profile_provider.dart';
import '../../widgets/department_card.dart';
import '../../widgets/emergency_banner.dart';
import '../../widgets/hospital_card.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/user_avatar.dart';

/// Hospital Home Screen with hospital achievements, specialties, and emergency info
class HomeScreen extends StatelessWidget {
  final VoidCallback onBookAppointmentPressed;

  const HomeScreen({super.key, required this.onBookAppointmentPressed});

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final profile = profileProvider.profile;
    final patientName = profile?.fullName.split(' ').first ?? 'Patient';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header Greeting & Hospital Emblem ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${AppStrings.patientGreeting} ',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              patientName,
                              style: AppTypography.titleLarge.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppStrings.appName,
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  UserAvatar(
                    photoUrl: profile?.photoUrl,
                    initials: profile?.initials ?? 'WE',
                    radius: 22,
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // --- Hospital Hero Card ---
              HospitalCard(
                gradient: AppColors.heroCardGradient,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.stars_rounded,
                                  color: AppColors.accentAmber, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Super-Speciality Eye Care',
                                style: AppTypography.labelSmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Clear Vision.\nAdvanced Compassionate Care.',
                      style: AppTypography.displayMedium.copyWith(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Equipped with state-of-the-art micro-incision phaco, laser refractive systems & modular sterile OTs.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.accentMint,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryDark,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: onBookAppointmentPressed,
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label: Text(
                        'Book Doctor Consultation',
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.primaryDark,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // --- 24/7 Emergency Banner ---
              const EmergencyBanner(),

              const SizedBox(height: 24),

              // --- Hospital Achievements & Milestones ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppStrings.hospitalAchievements,
                    style: AppTypography.headlineMedium.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accentMint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Verified Excellence',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.25,
                ),
                itemCount: HospitalData.milestones.length,
                itemBuilder: (context, index) {
                  return StatCard(milestone: HospitalData.milestones[index]);
                },
              ),

              const SizedBox(height: 24),

              // --- Specialized Eye Care Departments ---
              Text(
                AppStrings.specializedDepartments,
                style: AppTypography.headlineMedium.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Comprehensive diagnostics, laser, and surgical ophthalmology sub-specialties.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              ...HospitalData.departments.map((dept) => DepartmentCard(
                    department: dept,
                    onTap: onBookAppointmentPressed,
                  )),

              const SizedBox(height: 16),

              // --- Hospital Facilities ---
              Text(
                AppStrings.hospitalFacilities,
                style: AppTypography.headlineMedium.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              HospitalCard(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: HospitalData.facilities.map((facility) {
                    final isLast = facility == HospitalData.facilities.last;
                    return Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.accentCyan,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(facility.icon,
                                  color: AppColors.primaryAccent, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    facility.name,
                                    style: AppTypography.titleMedium.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    facility.description,
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (!isLast)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Divider(),
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 20),

              // --- Hospital Timings & Location Card ---
              HospitalCard(
                backgroundColor: AppColors.surfaceSubtle,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.access_time_filled_rounded,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'OPD Timings',
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.opdTimings,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_rounded,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppStrings.hospitalAddress,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
