import 'package:weh_shared/weh_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/ui_helpers.dart';
import '../../../core/utils/validators.dart';
import '../../../state/auth_provider.dart';
import '../../../state/profile_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/hospital_card.dart';
import '../shell/main_shell_screen.dart';

/// First-time user profile setup screen after Google login
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _ageController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    final authUser = context.read<AuthProvider>().user;
    _nameController = TextEditingController(text: authUser?.displayName ?? '');
    _mobileController = TextEditingController();
    _ageController = TextEditingController();
    _emailController = TextEditingController(text: authUser?.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authUser = context.read<AuthProvider>().user;
    if (authUser == null) return;

    final profileProvider = context.read<ProfileProvider>();
    final age = int.tryParse(_ageController.text.trim()) ?? 0;

    final success = await profileProvider.createProfile(
      uid: authUser.uid,
      fullName: _nameController.text.trim(),
      mobileNumber: _mobileController.text.trim(),
      age: age,
      email: _emailController.text.trim(),
      photoUrl: authUser.photoUrl,
    );

    if (!mounted) return;

    if (success) {
      UiHelpers.showSnackBar(
        context,
        message: AppStrings.profileSetupSuccess,
        isSuccess: true,
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShellScreen()),
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

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Patient Registration'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header card
                HospitalCard(
                  gradient: AppColors.heroCardGradient,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.person_add_alt_1_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              AppStrings.completeProfileTitle,
                              style: AppTypography.titleLarge.copyWith(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        AppStrings.completeProfileSubtitle,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.accentMint,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Form Fields
                Text(
                  'Patient Information',
                  style: AppTypography.headlineMedium.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),

                // Full Name
                CustomTextField(
                  label: AppStrings.fullNameLabel,
                  hint: AppStrings.fullNameHint,
                  controller: _nameController,
                  prefixIcon: Icons.badge_rounded,
                  validator: Validators.validateFullName,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(70),
                  ],
                ),

                const SizedBox(height: 16),

                // Mobile Number
                CustomTextField(
                  label: AppStrings.mobileLabel,
                  hint: AppStrings.mobileHint,
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_android_rounded,
                  validator: Validators.validateMobileNumber,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  helperText: 'For appointment reminders and OPD alerts',
                ),

                const SizedBox(height: 16),

                // Age
                CustomTextField(
                  label: AppStrings.ageLabel,
                  hint: AppStrings.ageHint,
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.cake_rounded,
                  validator: Validators.validateAge,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                ),

                const SizedBox(height: 16),

                // Email (Read-only or editable)
                CustomTextField(
                  label: AppStrings.emailLabel,
                  controller: _emailController,
                  readOnly: true,
                  prefixIcon: Icons.email_rounded,
                  validator: (v) => Validators.validateEmail(v, isRequired: false),
                  helperText: 'Linked with your Google account',
                ),

                const SizedBox(height: 32),

                // Submit Button
                CustomButton.primary(
                  text: AppStrings.saveProfile,
                  isLoading: profileProvider.isLoading,
                  icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                  onPressed: profileProvider.isLoading
                      ? null
                      : () => _handleSaveProfile(),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
