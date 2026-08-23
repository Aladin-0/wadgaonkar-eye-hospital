import 'package:weh_shared/weh_shared.dart';
import 'package:flutter/material.dart';

/// Patient avatar widget supporting network image with graceful fallback to monogram initials
class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String initials;
  final double radius;
  final Color? backgroundColor;

  const UserAvatar({
    super.key,
    this.photoUrl,
    required this.initials,
    this.radius = 24,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? AppColors.accentMint,
        backgroundImage: NetworkImage(photoUrl!),
        onBackgroundImageError: (exception, stackTrace) {},
        child: null,
      );
    }

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.primaryGradient,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: AppTypography.labelLarge.copyWith(
            color: Colors.white,
            fontSize: radius * 0.75,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
