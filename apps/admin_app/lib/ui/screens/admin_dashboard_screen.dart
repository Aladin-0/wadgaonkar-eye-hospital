import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../state/admin_provider.dart';
import '../../theme/admin_theme.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _selectedFilter = 'today';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchDashboardData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final allAppts = provider.todayAppointments;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final weekEnd = today.add(const Duration(days: 7));

    final filtered = allAppts.where((a) {
      if (a['appointment_date'] == null) return false;
      try {
        final date = DateTime.parse(a['appointment_date'].toString());
        final apptDay = DateTime(date.year, date.month, date.day);
        switch (_selectedFilter) {
          case 'today':
            return apptDay == today;
          case 'tomorrow':
            return apptDay == tomorrow;
          case 'week':
            return !apptDay.isBefore(today) && !apptDay.isAfter(weekEnd);
          default:
            return apptDay == today;
        }
      } catch (_) {
        return false;
      }
    }).toList();

    filtered.sort((a, b) {
      final dateA = DateTime.tryParse(a['appointment_date']?.toString() ?? '') ?? DateTime(2099);
      final dateB = DateTime.tryParse(b['appointment_date']?.toString() ?? '') ?? DateTime(2099);
      final cmp = dateA.compareTo(dateB);
      if (cmp != 0) return cmp;
      final slotA = a['slot_start_time']?.toString() ?? '';
      final slotB = b['slot_start_time']?.toString() ?? '';
      return slotA.compareTo(slotB);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Premium Typography Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE, MMMM d').format(DateTime.now()),
                style: const TextStyle(
                  color: AdminTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Dashboard',
                style: TextStyle(
                  color: AdminTheme.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 32),
              // Dashboard Stats Row
              Row(
                children: [
                  _StatCard(
                    title: 'TOTAL APPTS',
                    count: filtered.length.toString(),
                  ),
                  const SizedBox(width: 16),
                  _StatCard(
                    title: 'CHECKED IN',
                    count: filtered.where((a) => a['booking_status'] == 'checkedIn').length.toString(),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        // Filter Tabs
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AdminTheme.borderColor)),
          ),
          child: Row(
            children: [
              _FilterTab(label: 'Today', value: 'today', selected: _selectedFilter, onTap: (v) => setState(() => _selectedFilter = v)),
              _FilterTab(label: 'Tomorrow', value: 'tomorrow', selected: _selectedFilter, onTap: (v) => setState(() => _selectedFilter = v)),
              _FilterTab(label: 'Next 7 Days', value: 'week', selected: _selectedFilter, onTap: (v) => setState(() => _selectedFilter = v)),
            ],
          ),
        ),

        // Appointments list
        Expanded(
          child: RefreshIndicator(
            onRefresh: provider.fetchDashboardData,
            color: AdminTheme.primaryColor,
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: AdminTheme.errorColor, size: 48),
                            const SizedBox(height: 16),
                            Text(provider.error!, style: const TextStyle(color: AdminTheme.errorColor)),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today_outlined, size: 48, color: AdminTheme.borderColor),
                                const SizedBox(height: 16),
                                Text(
                                  'No appointments for $_selectedFilter',
                                  style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 15, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(24),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final appt = filtered[index];
                              final status = appt['booking_status'] as String? ?? '';
                              final isRescheduled = appt['is_rescheduled'] == true;
                              
                              String slotFormatted = appt['slot_start_time']?.toString() ?? '';
                              try {
                                final dt = DateTime.parse(slotFormatted).toLocal();
                                slotFormatted = DateFormat('hh:mm a').format(dt);
                              } catch (_) {}
                              
                              String dateFormatted = appt['appointment_date']?.toString() ?? '';
                              try {
                                final d = DateTime.parse(dateFormatted);
                                dateFormatted = DateFormat('dd MMM').format(d);
                              } catch (_) {}

                              return Container(
                                decoration: BoxDecoration(
                                  color: AdminTheme.surfaceColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AdminTheme.borderColor),
                                ),
                                child: InkWell(
                                  onTap: () {},
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      children: [
                                        // Minimalist status indicator line
                                        Container(
                                          width: 4,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(status),
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      appt['patient_name'] ?? 'Unknown',
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w700,
                                                        fontSize: 16,
                                                        color: AdminTheme.textPrimary,
                                                        letterSpacing: -0.3,
                                                      ),
                                                    ),
                                                  ),
                                                  if (isRescheduled)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        border: Border.all(color: AdminTheme.textSecondary),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: const Text(
                                                        'RESCHEDULED',
                                                        style: TextStyle(fontSize: 9, color: AdminTheme.textSecondary, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Text(
                                                    '$dateFormatted · $slotFormatted',
                                                    style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                                                  ),
                                                  const Spacer(),
                                                  Text(
                                                    appt['appointment_code']?.toString().replaceFirst('WEH-', '') ?? '',
                                                    style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary, fontWeight: FontWeight.w600),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Icon(_getStatusIcon(status), size: 14, color: _getStatusColor(status)),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    _statusLabel(status).toUpperCase(),
                                                    style: TextStyle(
                                                      color: _getStatusColor(status),
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w800,
                                                      letterSpacing: 0.5,
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
                                ),
                              );
                            },
                          ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'confirmed': return AdminTheme.secondaryColor;
      case 'checkedIn': return AdminTheme.successColor;
      case 'completed': return AdminTheme.textSecondary;
      case 'cancelled': return AdminTheme.errorColor;
      case 'noShow': return AdminTheme.primaryColor;
      default: return AdminTheme.borderColor;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'confirmed': return Icons.thumb_up_alt_outlined;
      case 'checkedIn': return Icons.how_to_reg_outlined;
      case 'completed': return Icons.check_circle_outline;
      case 'cancelled': return Icons.cancel_outlined;
      case 'noShow': return Icons.person_off_outlined;
      default: return Icons.event_outlined;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'confirmed': return 'Confirmed';
      case 'checkedIn': return 'Checked In';
      case 'completed': return 'Completed';
      case 'cancelled': return 'Cancelled';
      case 'noShow': return 'No Show';
      case 'gracePeriod': return 'Grace Period';
      case 'needsReschedule': return 'Needs Reschedule';
      case 'pendingPayment': return 'Pending Payment';
      default: return status ?? 'Unknown';
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String count;

  const _StatCard({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AdminTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminTheme.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AdminTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              count,
              style: const TextStyle(
                color: AdminTheme.textPrimary,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;

  const _FilterTab({required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AdminTheme.primaryColor : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? AdminTheme.textPrimary : AdminTheme.textSecondary,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
