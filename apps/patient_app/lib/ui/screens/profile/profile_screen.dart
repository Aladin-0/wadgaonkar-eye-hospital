import 'package:weh_shared/weh_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/ui_helpers.dart';
import '../../../core/utils/validators.dart';
import '../../../core/constants/app_policies.dart';
import '../../../state/auth_provider.dart';
import '../../../state/profile_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/hospital_card.dart';
import '../../widgets/user_avatar.dart';
import '../auth/login_screen.dart';
import 'policy_view_screen.dart';

/// User Profile Screen with patient details, edit modal, and logout action
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showEditProfileModal(BuildContext context) {
    final profileProvider = context.read<ProfileProvider>();
    final currentProfile = profileProvider.profile;
    if (currentProfile == null) return;

    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: currentProfile.fullName);
    final mobileCtrl = TextEditingController(text: currentProfile.mobileNumber);
    final ageCtrl = TextEditingController(text: currentProfile.age.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: StatefulBuilder(
            builder: (ctx, setModalState) {
              final isSaving = profileProvider.isLoading;

              return Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppStrings.editProfile,
                            style: AppTypography.headlineMedium.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.of(modalCtx).pop(),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      const SizedBox(height: 8),

                      // Full Name
                      CustomTextField(
                        label: AppStrings.fullNameLabel,
                        hint: AppStrings.fullNameHint,
                        controller: nameCtrl,
                        prefixIcon: Icons.badge_rounded,
                        validator: Validators.validateFullName,
                        inputFormatters: [LengthLimitingTextInputFormatter(70)],
                      ),
                      const SizedBox(height: 14),

                      // Mobile Number
                      CustomTextField(
                        label: AppStrings.mobileLabel,
                        hint: AppStrings.mobileHint,
                        controller: mobileCtrl,
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_android_rounded,
                        validator: Validators.validateMobileNumber,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Age
                      CustomTextField(
                        label: AppStrings.ageLabel,
                        hint: AppStrings.ageHint,
                        controller: ageCtrl,
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.cake_rounded,
                        validator: Validators.validateAge,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      CustomButton.primary(
                        text: AppStrings.updateProfile,
                        isLoading: isSaving,
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setModalState(() {});

                                final age = int.tryParse(ageCtrl.text.trim()) ?? 0;
                                final success = await profileProvider.updateProfile(
                                  fullName: nameCtrl.text.trim(),
                                  mobileNumber: mobileCtrl.text.trim(),
                                  age: age,
                                  email: currentProfile.email,
                                );

                                if (modalCtx.mounted) {
                                  if (success) {
                                    Navigator.of(modalCtx).pop();
                                    UiHelpers.showSnackBar(
                                      context,
                                      message: AppStrings.profileUpdatedSuccess,
                                      isSuccess: true,
                                    );
                                  } else {
                                    if (profileProvider.errorMessage != null) {
                                      UiHelpers.showSnackBar(
                                        context,
                                        message: profileProvider.errorMessage!,
                                        isError: true,
                                      );
                                    }
                                  }
                                }
                              },
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await UiHelpers.showConfirmDialog(
      context,
      title: AppStrings.logoutConfirmTitle,
      message: AppStrings.logoutConfirmMessage,
      confirmText: AppStrings.confirm,
      isDestructive: true,
    );

    if (confirmed == true && context.mounted) {
      final authProvider = context.read<AuthProvider>();
      final profileProvider = context.read<ProfileProvider>();

      profileProvider.clearProfile();
      await authProvider.signOut();

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final profile = profileProvider.profile;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Patient Profile'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              // Patient ID & Profile Card
              HospitalCard(
                gradient: AppColors.primaryGradient,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        UserAvatar(
                          photoUrl: profile?.photoUrl,
                          initials: profile?.initials ?? 'WE',
                          radius: 30,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile?.fullName ?? 'Patient Name',
                                style: AppTypography.headlineMedium.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  profile?.patientId ?? 'WEH-PATIENT',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 10),
                    // Quick Stats Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildProfileStat(
                          label: 'Mobile',
                          value: profile?.formattedMobile ?? 'Not set',
                        ),
                        Container(width: 1, height: 24, color: Colors.white24),
                        _buildProfileStat(
                          label: 'Age',
                          value: profile != null && profile.age > 0
                              ? '${profile.age} Yrs'
                              : 'Not set',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Edit Profile Action Button
              CustomButton.outlined(
                text: AppStrings.editProfile,
                icon: const Icon(Icons.edit_note_rounded,
                    color: AppColors.primary, size: 22),
                onPressed: () => _showEditProfileModal(context),
              ),

              const SizedBox(height: 24),

              // Patient Record & Account Information Card
              HospitalCard(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    _buildSettingsTile(
                      icon: Icons.person_outline_rounded,
                      title: 'Full Name',
                      subtitle: profile?.fullName ?? 'Not available',
                    ),
                    const Divider(),
                    _buildSettingsTile(
                      icon: Icons.phone_android_rounded,
                      title: 'Registered Mobile',
                      subtitle: profile?.formattedMobile ?? 'Not available',
                    ),
                    const Divider(),
                    _buildSettingsTile(
                      icon: Icons.cake_outlined,
                      title: 'Patient Age',
                      subtitle: profile != null && profile.age > 0
                          ? '${profile.age} Years'
                          : 'Not set',
                    ),
                    if (profile?.email != null && profile!.email!.isNotEmpty) ...[
                      const Divider(),
                      _buildSettingsTile(
                        icon: Icons.mail_outline_rounded,
                        title: 'Google Email',
                        subtitle: profile.email!,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Legal & Policies Card
              HospitalCard(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      child: Text(
                        'Legal & Policies',
                        style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.primary),
                      title: Text('Privacy Policy', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PolicyViewScreen(title: 'Privacy Policy', markdownContent: AppPolicies.privacyPolicy)),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: const Icon(Icons.gavel_rounded, color: AppColors.primary),
                      title: Text('Terms & Conditions', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PolicyViewScreen(title: 'Terms & Conditions', markdownContent: AppPolicies.termsAndConditions)),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: const Icon(Icons.event_busy_rounded, color: AppColors.primary),
                      title: Text('Cancellation & Rescheduling', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PolicyViewScreen(title: 'Cancellation Policy', markdownContent: AppPolicies.cancellationPolicy)),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: const Icon(Icons.support_agent_rounded, color: AppColors.primary),
                      title: Text('Contact Us', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PolicyViewScreen(title: 'Contact Us', markdownContent: AppPolicies.contactUs)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Hospital Contact Card
              HospitalCard(
                backgroundColor: AppColors.surfaceSubtle,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_hospital_rounded,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          AppStrings.hospitalInfoTitle,
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Helpline: ${AppStrings.hospitalPhone}',
                      style: AppTypography.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Emergency: ${AppStrings.emergencyPhone}',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Email: ${AppStrings.hospitalEmail}',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Logout Button
              CustomButton(
                text: AppStrings.logout,
                backgroundColor: AppColors.errorLight,
                textColor: AppColors.error,
                icon: const Icon(Icons.logout_rounded,
                    color: AppColors.error, size: 20),
                onPressed: () => _handleLogout(context),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileStat({required String label, required String value}) {
    return Column(
      children: [
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.labelLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accentMint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
