import 'package:weh_shared/weh_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_policies.dart';
import '../../../state/auth_provider.dart';
import '../../../state/booking_provider.dart';
import '../../../state/profile_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/hospital_card.dart';
import '../profile/policy_view_screen.dart';
import 'appointment_receipt_screen.dart';
import '../../../data/services/payment_gateway_service.dart';

class BookingFlowScreen extends StatefulWidget {
  final Doctor? initialDoctor;
  final HospitalService? initialService;

  const BookingFlowScreen({
    super.key,
    this.initialDoctor,
    this.initialService,
  });

  @override
  State<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends State<BookingFlowScreen> {
  String _paymentOption = 'online'; // 'desk' or 'online'
  bool _termsAccepted = false;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bookingProvider = context.read<BookingProvider>();
      final authProvider = context.read<AuthProvider>();

      bookingProvider.initCatalog(patientUid: authProvider.user?.uid);

      if (widget.initialDoctor != null) {
        bookingProvider.selectDoctor(widget.initialDoctor!);
      }
      if (widget.initialService != null) {
        bookingProvider.selectService(widget.initialService!);
      }
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _onProceedToBooking() async {
    final bookingProvider = context.read<BookingProvider>();
    final profileProvider = context.read<ProfileProvider>();
    final profile = profileProvider.profile;

    if (profile == null || !profile.isProfileComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete your patient profile before booking.'),
          backgroundColor: AppColors.accentAmber,
        ),
      );
      return;
    }

    if (_paymentOption == 'desk') {
      final appt = await bookingProvider.bookPayAtDesk(profile: profile);
      if (appt != null && mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => AppointmentReceiptScreen(appointment: appt),
            transitionDuration: const Duration(milliseconds: 300),
            transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
          ),
        );
      }
    } else {
      try {
        final paymentService = context.read<IPaymentGatewayService>();

        // Step 1: Create the appointment in pendingPayment state to get a real server ID
        final pendingAppt = await bookingProvider.createPendingOnlineBooking(profile: profile);
        if (pendingAppt == null || !mounted) return;

        // Step 2: Initiate payment order on server using the real appointment ID
        // Amount is NOT sent from client — server derives it from the appointment
        final session = await paymentService.initiateOrder(
          amount: 0, // server ignores this; derives amount from appointment
          appointmentId: pendingAppt.id,
          patientName: profile.fullName,
          patientMobile: profile.mobileNumber,
          patientEmail: (profile.email?.isNotEmpty ?? false) ? profile.email! : 'noreply@weh.in',
        );

        if (!mounted) return;

        // Step 3: Launch Razorpay SDK and verify signature server-side
        final result = await paymentService.launchAndVerify(session: session);

        if (!mounted) return;

        if (result.isSuccess) {
          // Step 4: Confirm booking as paid on our backend
          final appt = await bookingProvider.confirmOnlineBooking(
            appointmentId: pendingAppt.id,
            paymentTransactionId: result.transactionId ?? session.merchantTransactionId,
          );
          if (appt != null && mounted) {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => AppointmentReceiptScreen(appointment: appt),
                transitionDuration: const Duration(milliseconds: 300),
                transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
              ),
            );
          }
        } else {
          // Cancel the pending appointment so the slot is freed
          await bookingProvider.cancelPendingBooking(pendingAppt.id);
          if (mounted) _showPaymentFailed(result.errorMessage ?? 'Payment unsuccessful.');
        }
      } catch (e) {
        if (mounted) _showPaymentFailed(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  void _showPaymentFailed(String message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) => Container(
        padding: const EdgeInsets.all(28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'Payment Unsuccessful',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _onProceedToBooking();
                },
                child: Text('Try Again', style: AppTypography.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookingProvider = context.watch<BookingProvider>();
    final currentStep = bookingProvider.currentStep;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _getStepTitle(currentStep),
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (currentStep > 0) {
              bookingProvider.prevStep();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Cancel Booking',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: bookingProvider.isCatalogLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Column(
              children: [
                // Step Indicator Bar
                _buildStepIndicator(currentStep),

                // Error Banner
                if (bookingProvider.errorMessage != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accentAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.accentAmber.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.accentAmber, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            bookingProvider.errorMessage!,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Main Step Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: _buildStepContent(currentStep, bookingProvider),
                  ),
                ),

                // Bottom Action Button
                _buildBottomBar(currentStep, bookingProvider),
              ],
            ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Select Doctor';
      case 1:
        return 'Select Service';
      case 2:
        return 'Select Date & Slot';
      case 3:
        return 'Review & Confirm OPD';
      default:
        return 'Book Appointment';
    }
  }

  Widget _buildStepIndicator(int currentStep) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          _buildStepNode(0, 'Doctor', currentStep),
          _buildStepConnector(currentStep > 0),
          _buildStepNode(1, 'Service', currentStep),
          _buildStepConnector(currentStep > 1),
          _buildStepNode(2, 'Slot', currentStep),
          _buildStepConnector(currentStep > 2),
          _buildStepNode(3, 'Review', currentStep),
        ],
      ),
    );
  }

  Widget _buildStepNode(int index, String label, int currentStep) {
    final isCompleted = currentStep > index;
    final isCurrent = currentStep == index;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isCompleted || isCurrent ? AppColors.primary : AppColors.surfaceSubtle,
            shape: BoxShape.circle,
            border: Border.all(
              color: isCurrent ? AppColors.primaryDark : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isCurrent ? Colors.white : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: isCurrent ? AppColors.primaryDark : AppColors.textSecondary,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector(bool isActive) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
        color: isActive ? AppColors.primary : AppColors.border,
      ),
    );
  }

  Widget _buildStepContent(int step, BookingProvider provider) {
    switch (step) {
      case 0:
        return _buildDoctorSelectionStep(provider);
      case 1:
        return _buildServiceSelectionStep(provider);
      case 2:
        return _buildDateAndSlotStep(provider);
      case 3:
        return _buildReviewAndPaymentStep(provider);
      default:
        return const SizedBox.shrink();
    }
  }

  // --- Step 0: Doctor Selection ---
  Widget _buildDoctorSelectionStep(BookingProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Eye Specialist Consultant',
          style: AppTypography.headlineMedium.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Select your preferred ophthalmologist for diagnosis and surgical consult.',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 14),
        ...provider.doctors.map((doctor) {
          final isSelected = provider.selectedDoctor?.id == doctor.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: HospitalCard(
              onTap: () => provider.selectDoctor(doctor),
              backgroundColor: isSelected ? AppColors.accentMint.withValues(alpha: 0.3) : Colors.white,
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 1.5 : 1,
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        doctor.name.replaceAll('Dr. ', '').split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join(),
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                doctor.name,
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accentCyan,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '₹${doctor.consultationFee.toInt()}',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          doctor.qualification,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            doctor.specialization,
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.schedule_rounded, size: 13, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              '${doctor.formattedShiftStartTime} - ${doctor.formattedShiftEndTime}',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // --- Step 1: Service Selection ---
  Widget _buildServiceSelectionStep(BookingProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Consultation Service',
          style: AppTypography.headlineMedium.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose the eye clinical service or evaluation you need.',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 14),
        ...provider.services.map((service) {
          final isSelected = provider.selectedService?.id == service.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: HospitalCard(
              onTap: () => provider.selectService(service),
              backgroundColor: isSelected ? AppColors.accentMint.withValues(alpha: 0.3) : Colors.white,
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 1.5 : 1,
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.accentCyan,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.remove_red_eye_rounded,
                      color: isSelected ? Colors.white : AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                service.title,
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Text(
                              '₹${service.baseFee.toInt()}',
                              style: AppTypography.labelMedium.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          service.department,
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          service.description,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // --- Step 2: Date & Slot Selection ---
  // ─── NEW EDITORIAL & TIMELINE DESIGN ───
  Widget _buildDateAndSlotStep(BookingProvider provider) {
    final now = DateTime.now();
    final dates = List.generate(7, (i) => now.add(Duration(days: i)));

    final morningSlots = provider.availableSlots.where((s) => s.period == SlotPeriod.morning).toList();
    final afternoonSlots = provider.availableSlots.where((s) => s.period == SlotPeriod.afternoon).toList();
    final eveningSlots = provider.availableSlots.where((s) => s.period == SlotPeriod.evening).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. EDITORIAL DATE HEADER
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${provider.selectedDate.day}',
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w900,
                height: 0.9,
                color: const Color(0xFF0B2447),
                letterSpacing: -2,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(provider.selectedDate).toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                    letterSpacing: 2.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('EEEE').format(provider.selectedDate),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF00B4D8),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
              ],
            )
          ],
        ),
        const SizedBox(height: 24),

        // 2. MINIMALIST DATE STRIP
        SizedBox(
          height: 68,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: dates.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, idx) {
              final d = dates[idx];
              final isSelected = d.year == provider.selectedDate.year &&
                  d.month == provider.selectedDate.month &&
                  d.day == provider.selectedDate.day;

              return GestureDetector(
                onTap: () => provider.selectDate(d),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150), // was 300ms
                  curve: Curves.easeOut,
                  width: 54,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF0B2447) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF0B2447) : AppColors.border.withOpacity(0.5),
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: const Color(0xFF0B2447).withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('E').format(d)[0],
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF00B4D8) : AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${d.day}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 40),

        // 3. CONTINUOUS VERTICAL TIMELINE FOR SLOTS
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0.0, 0.05), end: Offset.zero).animate(animation),
                child: child,
              ),
            );
          },
          child: SizedBox(
            key: ValueKey<String>('${provider.selectedDate.toIso8601String()}_${provider.availableSlots.length}'),
            width: double.infinity,
            child: provider.availableSlots.isEmpty
                ? _buildEmptySlotsState()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (morningSlots.isNotEmpty)
                        _buildTimelineNode(
                          'Morning Session',
                          '09:00 AM - 12:00 PM',
                          Icons.wb_sunny_rounded,
                          morningSlots,
                          provider,
                          isLast: afternoonSlots.isEmpty && eveningSlots.isEmpty,
                        ),
                      if (afternoonSlots.isNotEmpty)
                        _buildTimelineNode(
                          'Afternoon Session',
                          '12:00 PM - 04:00 PM',
                          Icons.wb_twilight_rounded,
                          afternoonSlots,
                          provider,
                          isLast: eveningSlots.isEmpty,
                        ),
                      if (eveningSlots.isNotEmpty)
                        _buildTimelineNode(
                          'Evening Session',
                          '04:00 PM - 07:30 PM',
                          Icons.nights_stay_rounded,
                          eveningSlots,
                          provider,
                          isLast: true,
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySlotsState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, spreadRadius: 5)
            ]),
            child: const Icon(Icons.event_busy_rounded, color: AppColors.textSecondary, size: 36),
          ),
          const SizedBox(height: 20),
          Text('No Appointments Available', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
            'The specialist is unavailable or the clinic is closed on this date. Please select a different day.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineNode(String title, String subtitle, IconData icon, List<TimeSlot> slots, BookingProvider provider, {required bool isLast}) {
    // NOTE: Removed IntrinsicHeight which is O(n²) expensive on long slot lists.
    // Using Column + fixed line instead which renders in O(n).
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline graphics
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B2447),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: const Color(0xFF0B2447).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  child: Icon(icon, color: const Color(0xFF00B4D8), size: 14),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 60, // fixed height instead of Expanded (avoids IntrinsicHeight)
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0B2447))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.5)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: slots.map((slot) {
                      final isSelected = provider.selectedSlot?.id == slot.id;
                      final isSelectable = slot.isSelectable;

                      return GestureDetector(
                        onTap: isSelectable ? () => provider.selectSlot(slot) : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150), // was 300ms - now snappy
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF00B4D8) : (isSelectable ? Colors.white : AppColors.surfaceSubtle.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF00B4D8) : (isSelectable ? AppColors.border : AppColors.border.withOpacity(0.2)),
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [BoxShadow(color: const Color(0xFF00B4D8).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
                                : [],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                slot.displayTime,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : (isSelectable ? AppColors.textPrimary : AppColors.textSecondary.withOpacity(0.4)),
                                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                  decoration: !isSelectable ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              if (!isSelectable && slot.unavailabilityReason != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  slot.unavailabilityReason!.toUpperCase(),
                                  style: TextStyle(
                                    color: slot.unavailabilityReason == 'Break' ? Colors.orange.withOpacity(0.8) : AppColors.textSecondary.withOpacity(0.5),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
  }

  // --- Step 3: Review & Payment Step ---
  Widget _buildReviewAndPaymentStep(BookingProvider provider) {
    final profile = context.watch<ProfileProvider>().profile;
    final doctor = provider.selectedDoctor;
    final service = provider.selectedService;
    final slot = provider.selectedSlot;

    final finalFee = provider.finalFee > 0 ? provider.finalFee : (doctor?.consultationFee ?? 600.0);
    final originalFee = provider.originalFee > 0 ? provider.originalFee : (doctor?.consultationFee ?? 600.0);
    final isDiscounted = provider.isDiscountApplied;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // OPD Case Paper Summary Card
        HospitalCard(
          backgroundColor: Colors.white,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'OPD Appointment Summary',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accentMint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Ready to Confirm',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Patient Info Row
              _buildSummaryRow(
                Icons.person_rounded,
                'Patient Name',
                '${profile?.fullName ?? "Patient"} (${profile?.age ?? 0} Yrs)',
              ),
              const SizedBox(height: 10),
              _buildSummaryRow(
                Icons.badge_rounded,
                'Hospital Patient ID',
                profile?.patientId.isNotEmpty == true ? profile!.patientId : 'WEH-New',
              ),
              const SizedBox(height: 10),
              _buildSummaryRow(
                Icons.medical_services_rounded,
                'Specialist Consultant',
                doctor?.name ?? '',
                subValue: doctor?.specialization,
              ),
              const SizedBox(height: 10),
              _buildSummaryRow(
                Icons.remove_red_eye_rounded,
                'Eye Care Service',
                service?.title ?? '',
              ),
              const SizedBox(height: 10),
              _buildSummaryRow(
                Icons.calendar_today_rounded,
                'Date & Time Slot',
                '${DateFormat('EEE, dd MMM yyyy').format(provider.selectedDate)} | ${slot?.displayRange ?? ""}',
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Fee Breakdown Card
        HospitalCard(
          backgroundColor: AppColors.surfaceSubtle,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Doctor Consultation Fee', style: AppTypography.bodySmall),
                  Text('₹${originalFee.toInt()}', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 6),
              if (isDiscounted) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Discount Applied', style: AppTypography.bodySmall.copyWith(color: Colors.green.shade700)),
                    Text(
                      '-₹${(originalFee - finalFee).toInt()}',
                      style: AppTypography.bodyMedium.copyWith(color: Colors.green.shade700, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                if (provider.discountMessage.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.shade200, width: 1),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1.0),
                          child: Icon(Icons.verified_rounded, color: Colors.green.shade700, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            provider.discountMessage,
                            style: AppTypography.bodySmall.copyWith(color: Colors.green.shade800, fontSize: 12, fontWeight: FontWeight.w600, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Hospital Digital Registration', style: AppTypography.bodySmall),
                  Text('FREE', style: AppTypography.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                ],
              ),
              const Divider(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Payable',
                    style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '₹${finalFee.toInt()}',
                    style: AppTypography.titleLarge.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Payment Method Selector
        Text(
          'Select Payment Method',
          style: AppTypography.headlineMedium.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),



        // Option 2: Online Payment (Razorpay Gateway Architecture)
        HospitalCard(
          onTap: () => setState(() => _paymentOption = 'online'),
          backgroundColor: _paymentOption == 'online' ? AppColors.accentMint.withValues(alpha: 0.3) : Colors.white,
          border: Border.all(
            color: _paymentOption == 'online' ? AppColors.primary : AppColors.border,
            width: _paymentOption == 'online' ? 1.5 : 1,
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                _paymentOption == 'online' ? Icons.radio_button_checked : Icons.radio_button_off,
                color: _paymentOption == 'online' ? AppColors.primary : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Online Payment (UPI / Cards / Netbanking)',
                          style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pre-pay digitally via Razorpay gateway with instant verification.',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Terms & Conditions Checkbox
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _termsAccepted,
                activeColor: AppColors.primary,
                onChanged: (val) {
                  setState(() {
                    _termsAccepted = val ?? false;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'I have read and agree to the ',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.4),
                  children: [
                    TextSpan(
                      text: 'Terms & Conditions',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                      recognizer: TapGestureRecognizer()..onTap = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PolicyViewScreen(title: 'Terms & Conditions', markdownContent: AppPolicies.termsAndConditions))),
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Cancellation Policy',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                      recognizer: TapGestureRecognizer()..onTap = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PolicyViewScreen(title: 'Cancellation Policy', markdownContent: AppPolicies.cancellationPolicy))),
                    ),
                    const TextSpan(text: '. (No refunds on cancellations)'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value, {String? subValue}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
              Text(
                value,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              if (subValue != null)
                Text(
                  subValue,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(int currentStep, BookingProvider provider) {
    bool isNextEnabled = false;
    String buttonText = 'Continue';

    switch (currentStep) {
      case 0:
        isNextEnabled = provider.selectedDoctor != null;
        buttonText = 'Next: Select Service';
        break;
      case 1:
        isNextEnabled = provider.selectedService != null;
        buttonText = 'Next: Select Date & Slot';
        break;
      case 2:
        isNextEnabled = provider.selectedSlot != null;
        buttonText = 'Next: Review Booking';
        break;
      case 3:
        isNextEnabled = !provider.isBookingLoading && _termsAccepted;
        buttonText = _paymentOption == 'desk' ? 'Confirm OPD Appointment' : 'Proceed to Pay & Confirm';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: CustomButton.primary(
          text: buttonText,
          isLoading: provider.isBookingLoading,
          onPressed: isNextEnabled
              ? () async {
                  if (currentStep < 3) {
                    if (currentStep == 2) {
                      final profile = context.read<ProfileProvider>().profile;
                      await provider.calculateFinalFee(profile?.uid ?? '');
                    }
                    provider.nextStep();
                  } else {
                    _onProceedToBooking();
                  }
                }
              : null,
        ),
      ),
    );
  }
}
