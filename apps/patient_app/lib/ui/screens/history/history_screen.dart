import 'package:weh_shared/weh_shared.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/auth_provider.dart';
import '../../../state/booking_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/hospital_card.dart';
import '../booking/appointment_receipt_screen.dart';

/// Appointment History & Case Records screen with dynamic tabs and pass view
class HistoryScreen extends StatefulWidget {
  final void Function([Appointment?]) onBookAppointmentPressed;

  const HistoryScreen({super.key, required this.onBookAppointmentPressed});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.user?.uid != null) {
        context.read<BookingProvider>().loadPatientAppointments(authProvider.user!.uid);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.user?.uid != null) {
        context.read<BookingProvider>().loadPatientAppointments(authProvider.user!.uid);
      }
    }
  }

  // ignore: unused_element
  void _showCancelDialog(Appointment appt) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Cancel Appointment?',
          style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel appointment ${appt.appointmentCode} with ${appt.doctorName}?',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for cancellation (optional)',
                hintText: 'e.g. Schedule conflict',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep Appointment'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final auth = context.read<AuthProvider>();
              final success = await context.read<BookingProvider>().cancelAppointment(
                    appointmentId: appt.id,
                    reason: reasonController.text.trim().isNotEmpty
                        ? reasonController.text.trim()
                        : 'Cancelled by patient',
                    patientUid: auth.user?.uid ?? '',
                  );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Appointment cancelled successfully' : 'Failed to cancel appointment'),
                    backgroundColor: success ? AppColors.textPrimary : AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Confirm Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRescheduleDialog(Appointment appt) {
    widget.onBookAppointmentPressed(appt);
  }

  @override
  Widget build(BuildContext context) {
    final bookingProvider = context.watch<BookingProvider>();
    final auth = context.watch<AuthProvider>();

    final upcoming = bookingProvider.upcomingAppointments;
    final completed = bookingProvider.completedAppointments;
    final cancelled = bookingProvider.cancelledAppointments;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.historyTitle),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w700),
          unselectedLabelStyle: AppTypography.labelMedium,
          tabs: [
            Tab(text: 'Upcoming (${upcoming.length})'),
            Tab(text: 'Past (${completed.length})'),
            Tab(text: 'Cancelled (${cancelled.length})'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (auth.user?.uid != null) {
            await bookingProvider.loadPatientAppointments(auth.user!.uid);
          }
        },
        color: AppColors.primary,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildAppointmentList(
              appointments: upcoming,
              emptyTitle: 'No Upcoming Appointments',
              emptySubtitle: 'Your confirmed OPD consultations and scheduled slots will appear here.',
              emptyIcon: Icons.calendar_month_rounded,
              showBookButton: true,
              isUpcoming: true,
            ),
            _buildAppointmentList(
              appointments: completed,
              emptyTitle: 'No Past Visits',
              emptySubtitle: 'Completed consultation history and clinical records will appear here.',
              emptyIcon: Icons.history_rounded,
              showBookButton: false,
              isUpcoming: false,
            ),
            _buildAppointmentList(
              appointments: cancelled,
              emptyTitle: 'No Cancelled Appointments',
              emptySubtitle: 'Cancelled or rescheduled appointment logs will be saved here.',
              emptyIcon: Icons.event_busy_rounded,
              showBookButton: false,
              isUpcoming: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentList({
    required List<Appointment> appointments,
    required String emptyTitle,
    required String emptySubtitle,
    required IconData emptyIcon,
    required bool showBookButton,
    required bool isUpcoming,
  }) {
    if (appointments.isEmpty) {
      return _buildEmptyState(
        title: emptyTitle,
        subtitle: emptySubtitle,
        icon: emptyIcon,
        showButton: showBookButton,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final auth = context.read<AuthProvider>();
        if (auth.user?.uid != null) {
          await context.read<BookingProvider>().loadPatientAppointments(auth.user!.uid);
        }
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final appt = appointments[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _buildAppointmentCard(appt, isUpcoming),
        );
      },
      ),
    );
  }

  Widget _buildAppointmentCard(Appointment appt, bool isUpcoming) {
    return HospitalCard(
      backgroundColor: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Code & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  appt.appointmentCode,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _buildStatusBadge(appt),
            ],
          ),
          const SizedBox(height: 12),

          // Doctor & Service
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentMint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.medical_services_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appt.doctorName,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      appt.doctorSpecialization,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      appt.serviceTitle,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 20),

          // Date & Time Row
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                '${appt.formattedDate} • ${appt.formattedSlotTime}',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              Text(
                'Fee: ₹${appt.consultationFee.toInt()}',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Grace Period Alert Banner
          if (appt.bookingStatus == BookingStatus.gracePeriod) ...[  
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, size: 14, color: Colors.orange.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      appt.expiresAt != null
                          ? 'Grace period active. Slot expires at ${appt.expiresAt!.toLocal().toString().substring(11, 16)}.'
                          : 'You are in the grace period. Please arrive soon!',
                      style: TextStyle(fontSize: 11, color: Colors.orange.shade800, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Requires Rescheduling Alert
          if (appt.requiresRescheduling) ...[  
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Doctor unavailable. Please reschedule your appointment.',
                      style: TextStyle(fontSize: 11, color: Colors.red.shade800, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.qr_code_rounded, size: 16),
                  label: const Text('View OPD Pass', style: TextStyle(fontSize: 12)),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AppointmentReceiptScreen(appointment: appt),
                      ),
                    );
                  },
                ),
              ),
              if (isUpcoming && appt.bookingStatus.isActive) ...[
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.schedule_rounded, color: AppColors.primary, size: 20),
                  tooltip: 'Reschedule Appointment',
                  onPressed: () => _showRescheduleDialog(appt),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(Appointment appt) {
    Color color;
    Color bgColor;
    IconData? icon;

    switch (appt.bookingStatus) {
      case BookingStatus.confirmed:
        color = AppColors.primary;
        bgColor = AppColors.accentMint;
        icon = Icons.check_circle_outline_rounded;
        break;
      case BookingStatus.gracePeriod:
        color = Colors.orange.shade800;
        bgColor = Colors.orange.shade50;
        icon = Icons.timer_outlined;
        break;
      case BookingStatus.checkedIn:
        color = Colors.green.shade800;
        bgColor = Colors.green.shade50;
        icon = Icons.how_to_reg_rounded;
        break;
      case BookingStatus.completed:
        color = AppColors.primaryDark;
        bgColor = AppColors.surfaceSubtle;
        icon = Icons.task_alt_rounded;
        break;
      case BookingStatus.cancelled:
        color = AppColors.error;
        bgColor = AppColors.error.withValues(alpha: 0.1);
        icon = Icons.cancel_outlined;
        break;
      case BookingStatus.expired:
        color = Colors.grey.shade700;
        bgColor = Colors.grey.shade100;
        icon = Icons.hourglass_disabled_rounded;
        break;
      case BookingStatus.noShow:
        color = Colors.deepOrange.shade700;
        bgColor = Colors.deepOrange.shade50;
        icon = Icons.person_off_outlined;
        break;
      case BookingStatus.rescheduled:
        color = Colors.indigo.shade700;
        bgColor = Colors.indigo.shade50;
        icon = Icons.update_rounded;
        break;
      default:
        color = AppColors.textSecondary;
        bgColor = AppColors.surfaceSubtle;
        icon = null;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            appt.bookingStatus.displayName,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool showButton,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 30),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.accentMint,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.headlineMedium.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (showButton) ...[
            CustomButton.primary(
              text: 'Book New OPD Appointment',
              icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 18),
              onPressed: () => widget.onBookAppointmentPressed(),
            ),
          ],
        ],
      ),
    );
  }
}
