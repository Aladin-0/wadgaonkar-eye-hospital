import 'package:flutter/material.dart';
import 'package:weh_shared/weh_shared.dart';

class HospitalStorySection extends StatelessWidget {
  const HospitalStorySection({super.key});

  final List<Map<String, String>> _stories = const [
    {
      'image': 'assets/images/hospital/main.jpeg',
      'title': 'A Legacy of Excellence',
      'subtitle': 'Founded with a vision to eradicate preventable blindness, Wadgaonkar Eye Hospital has been a pillar of trust in Sambhajinagar.',
    },
    {
      'image': 'assets/images/hospital/entrance.jpeg',
      'title': 'State-of-the-Art Facilities',
      'subtitle': 'Experience world-class eye care with our ultra-clean modular operation theaters and 3D OCT imaging technology.',
    },
    {
      'image': 'assets/images/hospital/inside_angle.jpeg',
      'title': 'Expert Precision',
      'subtitle': 'Led by Dr. Swapnil Wadgaonkar, our team specializes in Intralase Blade-Free LASIK and advanced microsurgery.',
    },
    {
      'image': 'assets/images/hospital/closeup.jpeg',
      'title': 'Accessible For All',
      'subtitle': 'Empanelled with PM-JAY and major insurance providers to ensure every patient receives the best possible treatment.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Our Story',
                style: AppTypography.headlineLarge.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryDark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Over two decades of restoring vision.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ...List.generate(_stories.length, (index) {
          final isEven = index % 2 == 0;
          return _buildStoryBlock(
            context,
            _stories[index],
            isEven,
            index == _stories.length - 1,
          );
        }),
      ],
    );
  }

  Widget _buildStoryBlock(BuildContext context, Map<String, String> story, bool isEven, bool isLast) {
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Section
          Container(
            height: 240,
            width: double.infinity,
            margin: EdgeInsets.only(
              left: isEven ? 20 : 0,
              right: isEven ? 0 : 20,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.horizontal(
                left: isEven ? const Radius.circular(32) : Radius.zero,
                right: isEven ? Radius.zero : const Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.horizontal(
                left: isEven ? const Radius.circular(32) : Radius.zero,
                right: isEven ? Radius.zero : const Radius.circular(32),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    story['image']!,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          AppColors.primaryDark.withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Text Content that overlaps the image slightly
          Transform.translate(
            offset: const Offset(0, -30),
            child: Container(
              margin: EdgeInsets.only(
                left: isEven ? 40 : 20,
                right: isEven ? 20 : 40,
              ),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    story['title']!,
                    style: AppTypography.titleLarge.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    story['subtitle']!,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ));
  }
}
