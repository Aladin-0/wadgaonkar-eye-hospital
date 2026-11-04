import 'package:weh_shared/weh_shared.dart';
import 'package:flutter/material.dart';

/// A bento-box style widget that perfectly matches the mockup design
/// for Wadgaonkar Eye Hospital Milestones.
class MilestonesBentoGrid extends StatelessWidget {
  const MilestonesBentoGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 11,
                child: _buildYearsCard(),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 9,
                child: Column(
                  children: [
                    Expanded(child: _buildSurgeriesCard()),
                    const SizedBox(height: 12),
                    Expanded(child: _buildSatisfactionCard()),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildConsultationsCard(),
      ],
    );
  }

  Widget _buildYearsCard() {
    return _BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.military_tech_rounded,
                  color: AppColors.primaryDark,
                  size: 28,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_user_rounded, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'EST. 2002',
                      style: AppTypography.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '22+',
                style: AppTypography.displayLarge.copyWith(
                  color: const Color(0xFF0F172A),
                  fontSize: 40,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Years of\nExcellence',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Continuous technological leadership in ophthalmic microsurgery in Maharashtra.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurgeriesCard() {
    return _BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(
                Icons.visibility_rounded,
                color: AppColors.primaryDark,
                size: 22,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Verified',
                  style: AppTypography.labelSmall.copyWith(
                    color: const Color(0xFF059669),
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '80,000+',
            style: AppTypography.headlineMedium.copyWith(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Eye Surgeries\nDone',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.1,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSatisfactionCard() {
    return _BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(
                Icons.verified_rounded,
                color: Color(0xFFF59E0B),
                size: 22,
              ),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 14),
                  const SizedBox(width: 2),
                  Text(
                    '4.9/5',
                    style: AppTypography.labelSmall.copyWith(
                      color: const Color(0xFFB45309),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '99.2%',
            style: AppTypography.headlineMedium.copyWith(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Patient\nSatisfaction',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.1,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsultationsCard() {
    return _BentoCard(
      backgroundColor: const Color(0xFFEFF6FF),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.people_alt_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '6.5 Lakhs+ Outpatient Consultations',
                  style: AppTypography.titleMedium.copyWith(
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Trusted regional tertiary referral center across Western Maharashtra & Pan-India',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.primaryDark,
            size: 28,
          ),
        ],
      ),
    );
  }
}

class _BentoCard extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;

  const _BentoCard({
    required this.child,
    this.backgroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

extension _ConstrainedExtension on Widget {
  // ignore: unused_element
  Widget constrained({double? height, double? width}) {
    return SizedBox(
      height: height,
      width: width,
      child: this,
    );
  }
}
