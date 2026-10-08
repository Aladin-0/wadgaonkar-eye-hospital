import 'package:weh_shared/weh_shared.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/auth_provider.dart';
import '../../../state/booking_provider.dart';
import '../../../state/profile_provider.dart';
import '../../widgets/department_card.dart';
import '../../widgets/emergency_banner.dart';
import '../../widgets/hospital_card.dart';
import '../../widgets/hospital_story_carousel.dart';
import '../../widgets/milestones_bento_grid.dart';
import '../../widgets/user_avatar.dart';

/// Hospital Home Screen with hospital achievements, specialties, and emergency info
class HomeScreen extends StatefulWidget {
  final void Function([Appointment?]) onBookAppointmentPressed;

  const HomeScreen({super.key, required this.onBookAppointmentPressed});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final PageController _departmentsController = PageController(viewportFraction: 0.75, initialPage: 1);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _departmentsController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Auto-refresh appointments when app comes to foreground
      final auth = context.read<AuthProvider>();
      if (auth.user?.uid != null) {
        context.read<BookingProvider>().loadPatientAppointments(auth.user!.uid);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final bookingProvider = context.watch<BookingProvider>();
    final profile = profileProvider.profile;
    final patientName = profile?.fullName.split(' ').first ?? 'Patient';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            final auth = context.read<AuthProvider>();
            if (auth.user?.uid != null) {
              await context.read<BookingProvider>().loadPatientAppointments(auth.user!.uid);
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                      onPressed: () => widget.onBookAppointmentPressed(),
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

              const SizedBox(height: 16),

              if (bookingProvider.needsRescheduleAppointments.isNotEmpty) ...[
                GestureDetector(
                  onTap: () => widget.onBookAppointmentPressed(bookingProvider.needsRescheduleAppointments.first),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade300, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Action Required',
                                style: AppTypography.titleMedium.copyWith(color: Colors.red.shade800, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Your appointment on ${bookingProvider.needsRescheduleAppointments.first.formattedDate} was cancelled due to a doctor emergency. Tap here to reschedule for free.',
                                style: AppTypography.bodySmall.copyWith(color: Colors.red.shade900),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

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
              const MilestonesBentoGrid(),

              const SizedBox(height: 24),
              const HospitalStorySection(),

              const SizedBox(height: 24),

              // --- Specialized Eye Care Departments ---
              Text(
                AppStrings.specializedDepartments,
                style: AppTypography.headlineLarge.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
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
              SizedBox(
                height: 240,
                child: PageView.builder(
                  controller: _departmentsController,
                  physics: const BouncingScrollPhysics(),
                  itemCount: HospitalData.departments.length,
                  itemBuilder: (context, index) {
                    return AnimatedBuilder(
                      animation: _departmentsController,
                      builder: (context, child) {
                        double value = 1.0;
                        if (_departmentsController.position.haveDimensions) {
                          value = _departmentsController.page! - index;
                          value = (1 - (value.abs() * 0.3)).clamp(0.0, 1.0);
                        } else if (index != 0) {
                          value = 0.7;
                        }
                        
                        final double rotation = (1 - value) * -0.2; // slight 3D rotation
                        final double verticalOffset = (1 - value) * 40; // push down

                        return Center(
                          child: RepaintBoundary(
                            child: Transform(
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.001) // perspective
                                ..rotateZ(rotation)
                                ..translate(0.0, verticalOffset),
                              alignment: Alignment.center,
                              child: Opacity(
                                opacity: value.clamp(0.4, 1.0),
                                child: child,
                              ),
                            ),
                          ),
                        );
                      },
                      child: DepartmentCard(
                        department: HospitalData.departments[index],
                        onTap: () => widget.onBookAppointmentPressed(),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // --- Hospital Facilities ---
              Text(
                AppStrings.hospitalFacilities,
                style: AppTypography.headlineLarge.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                itemCount: HospitalData.facilities.length,
                itemBuilder: (context, index) {
                  final facility = HospitalData.facilities[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryDark.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.accentMint,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            facility.icon,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          facility.name,
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.primaryDark,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          facility.description,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
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
      ),
    );
  }
}
