import 'dart:async';
import 'package:weh_shared/weh_shared.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/services/firebase_service.dart';
import '../../../state/auth_provider.dart';
import '../../../state/booking_provider.dart';
import '../booking/booking_flow_screen.dart';
import '../history/history_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';

/// Main application shell with bottom navigation and hero booking action
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;
  StreamSubscription<bool>? _notificationSub;

  @override
  void initState() {
    super.initState();

    // Listen for FCM foreground messages → refresh + switch to Home tab
    _notificationSub = FirebaseService.onCancellationNotification.stream.listen((_) {
      if (!mounted) return;
      setState(() => _currentIndex = 0);
      _refreshAppointments();
    });

    // After first frame: check if we were launched/resumed via a notification tap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (FirebaseService.pendingCancellationRefresh) {
        FirebaseService.pendingCancellationRefresh = false; // consume the flag
        setState(() => _currentIndex = 0); // Ensure Home tab is selected
        _refreshAppointments();
      }
    });
  }

  void _refreshAppointments() {
    final auth = context.read<AuthProvider>();
    if (auth.user?.uid != null) {
      context.read<BookingProvider>().loadPatientAppointments(auth.user!.uid);
    }
  }


  @override
  void dispose() {
    _notificationSub?.cancel();
    super.dispose();
  }

  void _openBookingFlow([Appointment? rescheduleAppt]) {
    final provider = context.read<BookingProvider>();
    provider.resetDraft();
    if (rescheduleAppt != null) {
      provider.setRescheduleAppointment(rescheduleAppt);
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const BookingFlowScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeScreen(onBookAppointmentPressed: _openBookingFlow),
      HistoryScreen(onBookAppointmentPressed: _openBookingFlow),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (idx) {
              setState(() {
                _currentIndex = idx;
              });
            },
            backgroundColor: AppColors.surface,
            indicatorColor: AppColors.accentMint,
            elevation: 0,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_today_outlined),
                selectedIcon: Icon(Icons.calendar_today_rounded, color: AppColors.primary),
                label: 'Visits',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded, color: AppColors.primary),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _currentIndex != 1
          ? FloatingActionButton.extended(
              onPressed: () => _openBookingFlow(),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.add_rounded, size: 22),
              label: Text(
                'Book OPD',
                style: AppTypography.labelLarge.copyWith(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
    );
  }
}
