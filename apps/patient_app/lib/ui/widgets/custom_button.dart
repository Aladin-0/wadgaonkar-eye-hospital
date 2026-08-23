import 'package:weh_shared/weh_shared.dart';
import 'package:flutter/material.dart';

/// Premium button with gradient, loading indicator, and custom icons
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Widget? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final double height;
  final double borderRadius;
  final Gradient? gradient;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.height = 52,
    this.borderRadius = 14,
    this.gradient,
  });

  /// Factory for standard Gradient button
  factory CustomButton.primary({
    required String text,
    required VoidCallback? onPressed,
    bool isLoading = false,
    Widget? icon,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon,
      gradient: AppColors.primaryGradient,
      textColor: Colors.white,
    );
  }

  /// Factory for Outlined button
  factory CustomButton.outlined({
    required String text,
    required VoidCallback? onPressed,
    bool isLoading = false,
    Widget? icon,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      isOutlined: true,
      icon: icon,
      textColor: AppColors.primary,
    );
  }

  /// Factory for Google Sign-In button
  factory CustomButton.google({
    required String text,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      backgroundColor: Colors.white,
      textColor: AppColors.textPrimary,
      icon: Image.network(
        'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
        width: 22,
        height: 22,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.g_mobiledata_rounded,
          size: 28,
          color: Color(0xFF4285F4),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return SizedBox(
        width: double.infinity,
        height: height,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
          child: _buildChild(context, AppColors.primary),
        ),
      );
    }

    final decoration = BoxDecoration(
      gradient: onPressed == null
          ? null
          : (gradient ?? (backgroundColor == null ? AppColors.primaryGradient : null)),
      color: onPressed == null
          ? AppColors.border
          : (gradient == null ? (backgroundColor ?? AppColors.primary) : null),
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: onPressed == null
          ? []
          : [
              BoxShadow(
                color: (backgroundColor ?? AppColors.primary).withValues(alpha: 0.22),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
    );

    return Container(
      width: double.infinity,
      height: height,
      decoration: decoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: isLoading ? null : onPressed,
          child: Center(
            child: _buildChild(context, textColor ?? Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildChild(BuildContext context, Color color) {
    if (isLoading) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon!,
          const SizedBox(width: 12),
          Text(
            text,
            style: AppTypography.labelLarge.copyWith(
              color: color,
              fontSize: 15,
            ),
          ),
        ],
      );
    }

    return Text(
      text,
      style: AppTypography.labelLarge.copyWith(
        color: color,
        fontSize: 15,
      ),
    );
  }
}
