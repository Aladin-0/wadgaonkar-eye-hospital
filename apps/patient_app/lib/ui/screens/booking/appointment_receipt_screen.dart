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

            // Digital Pass Card
            HospitalCard(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Hospital Pass Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.appName,
                            style: AppTypography.titleMedium.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Super-Speciality Eye Care Center',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.primary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: appointment.paymentStatus == PaymentStatus.paid
                              ? AppColors.accentMint
                              : AppColors.accentCyan,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          appointment.paymentStatus.displayName,
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Appointment Code Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'APPOINTMENT CODE',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 9,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              appointment.appointmentCode,
                              style: AppTypography.titleLarge.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                          tooltip: 'Copy Code',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: appointment.appointmentCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Appointment code copied to clipboard'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // QR Code for OPD Desk Scanning
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: appointment.qrPayload,
                      version: QrVersions.auto,
                      size: 160,
                      gapless: false,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: AppColors.primaryDark,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scan at OPD Reception Desk for Instant Token Verification',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),

                  const Divider(height: 28),

                  // Appointment Details Table
                  _buildDetailRow('Patient Name', '${appointment.patientName} (${appointment.patientAge} Yrs)'),
                  const SizedBox(height: 8),
                  _buildDetailRow('Hospital Patient ID', appointment.patientId),
                  const SizedBox(height: 8),
                  _buildDetailRow('Doctor', appointment.doctorName, subValue: appointment.doctorSpecialization),
                  const SizedBox(height: 8),
                  _buildDetailRow('Service', appointment.serviceTitle),
                  const SizedBox(height: 8),
                  _buildDetailRow('Scheduled Date', appointment.formattedDate),
                  const SizedBox(height: 8),
                  _buildDetailRow('Time Window', appointment.formattedSlotTime),
                  const SizedBox(height: 8),
                  _buildDetailRow('Consultation Fee', '₹${appointment.consultationFee.toInt()}'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Hospital Location & Instructions
            HospitalCard(
              backgroundColor: AppColors.surfaceSubtle,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Important Patient Notice',
                          style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                        Text(
                          'Please report 10 minutes prior to your time slot. Bring prior eye prescriptions or glasses if available.',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            CustomButton.primary(
              text: 'Done',
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const MainShellScreen()),
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
