import 'package:weh_shared/weh_shared.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/ui_helpers.dart';
import '../../../state/auth_provider.dart';
import '../../../state/profile_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/hospital_card.dart';
import '../profile/profile_setup_screen.dart';
import '../shell/main_shell_screen.dart';

/// Hospital-branded Google Sign-In login screen
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Guard flag: prevents double-tap during OS Google account picker
  bool _isSigningIn = false;

  Future<void> _handleGoogleSignIn() async {
    // Prevent re-entrant calls (double-tap bug fix)
    if (_isSigningIn) return;
    setState(() => _isSigningIn = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signInWithGoogle();

    // Always reset the flag so button works again if cancelled
    if (!mounted) return;
    setState(() => _isSigningIn = false);

    if (!mounted) return;

    if (success && authProvider.user != null) {
      final profileProvider = context.read<ProfileProvider>();
      await profileProvider.loadProfile(authProvider.user!);

      if (!mounted) return;

      if (profileProvider.hasCompleteProfile) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const MainShellScreen(),
            transitionDuration: const Duration(milliseconds: 300),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const ProfileSetupScreen(),
            transitionDuration: const Duration(milliseconds: 300),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
        );
      }
    } else {
      if (authProvider.errorMessage != null) {
        UiHelpers.showSnackBar(
          context,
          message: authProvider.errorMessage!,
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    // Show loading if either the authProvider is loading OR our local sign-in guard is active
    final isLoading = authProvider.isAuthenticating || _isSigningIn;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: size.height - MediaQuery.of(context).padding.top - 32,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Hospital Emblem & Title
                Column(
                  children: [
                    const SizedBox(height: 20),
                    // Eye Emblem Icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.visibility_rounded,
                          size: 42,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      AppStrings.appName,
                      textAlign: TextAlign.center,
                      style: AppTypography.headlineLarge.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppStrings.appTagline,
                      textAlign: TextAlign.center,
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.primaryAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.hospitalSubtitle,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Trust Features Card
                HospitalCard(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Patient Portal Access',
                        style: AppTypography.titleLarge.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildFeatureItem(
                        icon: Icons.calendar_month_rounded,
                        title: 'Easy OPD Slot Booking',
                        subtitle: 'Consult leading eye specialists and surgeons directly.',
                      ),
                      const SizedBox(height: 12),
                      _buildFeatureItem(
                        icon: Icons.receipt_long_rounded,
                        title: 'Digital Health Records',
                        subtitle: 'Access prescriptions, vision test charts & diagnostics.',
                      ),
                      const SizedBox(height: 12),
                      _buildFeatureItem(
                        icon: Icons.shield_rounded,
                        title: 'Hospital Verified & Secure',
                        subtitle: 'NABH standards & private encrypted patient profile.',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Bottom Action: Google Sign In
                Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: CustomButton.google(
                        text: AppStrings.signInWithGoogle,
                        isLoading: isLoading,
                        onPressed: isLoading
                            ? null
                            : _handleGoogleSignIn,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppStrings.loginTerms,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppColors.accentMint,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
