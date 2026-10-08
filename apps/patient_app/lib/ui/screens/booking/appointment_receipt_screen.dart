import 'package:weh_shared/weh_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../widgets/custom_button.dart';
import '../../widgets/hospital_card.dart';
import '../shell/main_shell_screen.dart';

/// Digital Appointment Pass & Receipt Screen with QR code verification payload
class AppointmentReceiptScreen extends StatelessWidget {
  final Appointment appointment;

  const AppointmentReceiptScreen({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'OPD Appointment Pass',
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const MainShellScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // Success Header Badge
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentMint,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: 12),
            Text(
              'Booking Confirmed!',
              style: AppTypography.headlineMedium.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your OPD appointment token has been reserved at Wadgaonkar Eye Hospital.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),

            
            // ─── ULTRA-PREMIUM APPOINTMENT CARD ───────────────────────────
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 350), // was 800ms - now instant feeling
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(offset: Offset(0, 16 * (1 - value)), child: child),
              ),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF0B2447).withOpacity(0.35), blurRadius: 40, offset: const Offset(0, 20)),
                    BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 80, spreadRadius: -8, offset: const Offset(0, 8)),
                    BoxShadow(color: const Color(0xFF00B4D8).withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    // ── TOP HERO SECTION ──
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0B2447), Color(0xFF19376D)],
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Watermark Eye Icon
                          Positioned(
                            right: -30,
                            top: -10,
                            child: Icon(Icons.remove_red_eye_rounded, size: 140, color: Colors.white.withOpacity(0.03)),
                          ),
                          // Diagonal Shimmer Stripe
                          Positioned(
                            right: 20,
                            top: -50,
                            child: Transform.rotate(
                              angle: 0.5,
                              child: Container(width: 120, height: 200, color: Colors.white.withOpacity(0.03)),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                        child: const Icon(Icons.remove_red_eye_rounded, color: Colors.white, size: 18),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('WADGAONKAR', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                                          const Text('EYE HOSPITAL', style: TextStyle(color: Color(0xFF00B4D8), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 2)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  // Live Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(color: const Color(0xFF00B4D8).withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF00B4D8).withOpacity(0.5))),
                                    child: Row(
                                      children: [
                                        TweenAnimationBuilder<double>(
                                          tween: Tween(begin: 0.4, end: 1.0),
                                          duration: const Duration(milliseconds: 800),
                                          curve: Curves.easeInOut,
                                          builder: (context, val, child) => Opacity(
                                            opacity: val,
                                            child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF00B4D8), shape: BoxShape.circle)),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text('OPD PASS', style: TextStyle(color: Color(0xFF00B4D8), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('PATIENT', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2)),
                                      const SizedBox(height: 4),
                                      Text(appointment.patientName.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                      const SizedBox(height: 4),
                                      Text('AGE: ${appointment.patientAge} YRS', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('BOOKING REF', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2)),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                        child: Text(appointment.appointmentCode, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontFamily: 'monospace')),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ── MIDDLE: Specialist + Date row ──
                    Container(
                      color: const Color(0xFF0F2D52),
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Specialist
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('SPECIALIST', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 2)),
                                const SizedBox(height: 5),
                                Text(appointment.doctorName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, height: 1.2)),
                                const SizedBox(height: 4),
                                // Service colored tag
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    appointment.serviceTitle,
                                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Vertical divider with dots
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                            child: Column(
                              children: List.generate(4, (_) => Container(
                                width: 2, height: 4,
                                margin: const EdgeInsets.only(bottom: 4),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2)),
                              )),
                            ),
                          ),
                          // Date/Time
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('SCHEDULE', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 2)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF00B4D8)),
                                    const SizedBox(width: 6),
                                    Text(appointment.formattedDate, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF00B4D8)),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text(appointment.formattedSlotTime, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── PERFORATED DIVIDER ──
                    Container(
                      color: const Color(0xFF0A2240),
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          // Dashes
                          SizedBox(
                            height: 24,
                            child: LayoutBuilder(
                              builder: (context, constraints) => Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const SizedBox(width: 24),
                                  ...List.generate(
                                    ((constraints.maxWidth - 48) / 10).floor(),
                                    (_) => Container(width: 5, height: 1, color: Colors.white.withOpacity(0.18)),
                                  ),
                                  const SizedBox(width: 24),
                                ],
                              ),
                            ),
                          ),
                          // Cutout circles
                          Positioned(left: -16, child: Container(width: 32, height: 32, decoration: const BoxDecoration(color: AppColors.background, shape: BoxShape.circle))),
                          Positioned(right: -16, child: Container(width: 32, height: 32, decoration: const BoxDecoration(color: AppColors.background, shape: BoxShape.circle))),
                        ],
                      ),
                    ),

                    // ── BOTTOM: Fee + QR ──
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0A2240),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left: Fee breakdown
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('FEE BREAKDOWN', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 2)),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Consultation', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w600)),
                                    Text('₹${appointment.consultationFee.toInt()}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Registration', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w600)),
                                    const Text('FREE', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.w800)),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Container(height: 1, color: Colors.white.withOpacity(0.1)),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('TOTAL', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                                    Text('₹${appointment.consultationFee.toInt()}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                // Payment Status
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: appointment.paymentStatus == PaymentStatus.paid ? Colors.greenAccent.withOpacity(0.1) : Colors.orangeAccent.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: appointment.paymentStatus == PaymentStatus.paid ? Colors.greenAccent.withOpacity(0.25) : Colors.orangeAccent.withOpacity(0.25)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(appointment.paymentStatus == PaymentStatus.paid ? Icons.check_circle_rounded : Icons.info_outline_rounded, 
                                           color: appointment.paymentStatus == PaymentStatus.paid ? Colors.greenAccent : Colors.orangeAccent, size: 13),
                                      const SizedBox(width: 6),
                                      Text(appointment.paymentStatus.displayName, style: TextStyle(color: appointment.paymentStatus == PaymentStatus.paid ? Colors.greenAccent : Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Right: Standard Static QR Code
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              children: [
                                // Strictly standard QR code format: static, white background, no rounded corners, no shadows
                                Container(
                                  color: Colors.white,
                                  padding: const EdgeInsets.all(8),
                                  child: GestureDetector(
                                    onTap: () {
                                      showGeneralDialog(
                                        context: context,
                                        barrierDismissible: true,
                                        barrierLabel: 'Dismiss',
                                        pageBuilder: (context, anim1, anim2) => const SizedBox(),
                                        transitionDuration: const Duration(milliseconds: 300),
                                        transitionBuilder: (context, anim1, anim2, child) {
                                          return ScaleTransition(
                                            scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
                                            child: Dialog(
                                              backgroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                              child: Padding(
                                                padding: const EdgeInsets.all(24.0),
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      'SCAN AT CLINIC',
                                                      style: AppTypography.titleMedium.copyWith(color: AppColors.primaryDark, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                                                    ),
                                                    const SizedBox(height: 24),
                                                    QrImageView(
                                                      data: appointment.qrPayload,
                                                      version: QrVersions.auto,
                                                      size: 250,
                                                      padding: EdgeInsets.zero,
                                                      backgroundColor: Colors.white,
                                                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                                                      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                                                    ),
                                                    const SizedBox(height: 24),
                                                    Text(
                                                      'Show this to the receptionist',
                                                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                    child: QrImageView(
                                      data: appointment.qrPayload,
                                      version: QrVersions.auto,
                                      size: 110,
                                      padding: EdgeInsets.zero, // Padding handled by container
                                      backgroundColor: Colors.white,
                                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                                      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'SCAN AT CLINIC',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Action Buttons
            CustomButton.primary(
              text: 'Done',
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const MainShellScreen(),
                    transitionDuration: const Duration(milliseconds: 300),
                    transitionsBuilder: (_, anim, __, child) =>
                        FadeTransition(opacity: anim, child: child),
                  ),
                  (route) => false,
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {String? subValue}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              if (subValue != null)
                Text(
                  subValue,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
