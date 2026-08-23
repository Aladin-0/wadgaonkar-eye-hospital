import 'package:weh_shared/weh_shared.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../state/auth_provider.dart';
import '../../../state/booking_provider.dart';
import '../../../state/profile_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/hospital_card.dart';
import 'appointment_receipt_screen.dart';

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
  String _paymentOption = 'desk'; // 'desk' or 'online'
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
          MaterialPageRoute(
            builder: (_) => AppointmentReceiptScreen(appointment: appt),
          ),
        );
      }
    } else {
      // Online Payment simulation with verification
      final appt = await bookingProvider.bookWithOnlinePayment(
        profile: profile,
        paymentTransactionId: 'pay_rzp_${DateTime.now().millisecondsSinceEpoch}',
        signature: 'sig_${DateTime.now().millisecondsSinceEpoch}_verified',
      );

      if (appt != null && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => AppointmentReceiptScreen(appointment: appt),
          ),
        );
      }
    }
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
                              '${doctor.shiftStartTime} - ${doctor.shiftEndTime} (Mon-Sat)',
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
  Widget _buildDateAndSlotStep(BookingProvider provider) {
    final now = DateTime.now();
    final dates = List.generate(14, (i) => now.add(Duration(days: i)));

    final morningSlots = provider.availableSlots.where((s) => s.period == SlotPeriod.morning).toList();
    final afternoonSlots = provider.availableSlots.where((s) => s.period == SlotPeriod.afternoon).toList();
    final eveningSlots = provider.availableSlots.where((s) => s.period == SlotPeriod.evening).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date Selector Bar
        Text(
          'Select Appointment Date',
          style: AppTypography.headlineMedium.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 72,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: dates.length,
            itemBuilder: (context, idx) {
              final d = dates[idx];
              final isSelected = d.year == provider.selectedDate.year &&
                  d.month == provider.selectedDate.month &&
                  d.day == provider.selectedDate.day;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => provider.selectDate(d),
                  child: Container(
                    width: 58,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppColors.primaryDark : AppColors.border,
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('E').format(d).toUpperCase(),
                          style: TextStyle(
                            color: isSelected ? AppColors.accentMint : AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${d.day}',
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 20),

        // Available Slots Section
        Text(
          'Available OPD Slots (${DateFormat('EEE, dd MMM').format(provider.selectedDate)})',
          style: AppTypography.headlineMedium.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Slots are generated dynamically from doctor duty hours & duration.',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 14),

        if (provider.availableSlots.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.event_busy_rounded, color: AppColors.textSecondary, size: 36),
                  const SizedBox(height: 10),
                  Text(
                    'No OPD Slots on this day',
                    style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Doctor is not available or the hospital OPD is closed on this date. Please choose another date.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          )
        else ...[
          if (morningSlots.isNotEmpty) ...[
            _buildPeriodHeader('Morning OPD (09:00 AM - 12:00 PM)', Icons.wb_sunny_rounded),
            _buildSlotChipsGrid(morningSlots, provider),
            const SizedBox(height: 16),
          ],
          if (afternoonSlots.isNotEmpty) ...[
            _buildPeriodHeader('Afternoon OPD (12:00 PM - 04:00 PM)', Icons.wb_twilight_rounded),
            _buildSlotChipsGrid(afternoonSlots, provider),
            const SizedBox(height: 16),
          ],
          if (eveningSlots.isNotEmpty) ...[
            _buildPeriodHeader('Evening OPD (04:00 PM - 07:30 PM)', Icons.nights_stay_rounded),
            _buildSlotChipsGrid(eveningSlots, provider),
            const SizedBox(height: 16),
          ],
        ],
      ],
    );
  }

  Widget _buildPeriodHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            title,
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotChipsGrid(List<TimeSlot> slots, BookingProvider provider) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: slots.map((slot) {
        final isSelected = provider.selectedSlot?.id == slot.id;
        final isSelectable = slot.isSelectable;

        Color bgColor = Colors.white;
        Color textColor = AppColors.textPrimary;
        Color borderColor = AppColors.border;

        if (isSelected) {
          bgColor = AppColors.primary;
          textColor = Colors.white;
          borderColor = AppColors.primaryDark;
        } else if (!isSelectable) {
          bgColor = AppColors.surfaceSubtle.withValues(alpha: 0.6);
          textColor = AppColors.textSecondary.withValues(alpha: 0.6);
          borderColor = AppColors.border.withValues(alpha: 0.4);
        }

        return InkWell(
          onTap: isSelectable ? () => provider.selectSlot(slot) : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  slot.displayTime,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                if (!isSelectable && slot.unavailabilityReason != null)
                  Text(
                    slot.unavailabilityReason!,
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- Step 3: Review & Payment Step ---
  Widget _buildReviewAndPaymentStep(BookingProvider provider) {
    final profile = context.watch<ProfileProvider>().profile;
    final doctor = provider.selectedDoctor;
    final service = provider.selectedService;
    final slot = provider.selectedSlot;

    final fee = doctor?.consultationFee ?? 600.0;

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
                  Text('₹${fee.toInt()}', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 6),
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
                    '₹${fee.toInt()}',
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

        // Option 1: Pay at Hospital Desk (Recommended)
        HospitalCard(
          onTap: () => setState(() => _paymentOption = 'desk'),
          backgroundColor: _paymentOption == 'desk' ? AppColors.accentMint.withValues(alpha: 0.3) : Colors.white,
          border: Border.all(
            color: _paymentOption == 'desk' ? AppColors.primary : AppColors.border,
            width: _paymentOption == 'desk' ? 1.5 : 1,
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                _paymentOption == 'desk' ? Icons.radio_button_checked : Icons.radio_button_off,
                color: _paymentOption == 'desk' ? AppColors.primary : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pay at Hospital Reception Counter (Cash / UPI)',
                      style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    Text(
                      'Instant confirmed slot. Pay during arrival at the hospital billing desk.',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
                          style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ],
                    ),
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
        isNextEnabled = !provider.isBookingLoading;
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
              ? () {
                  if (currentStep < 3) {
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
