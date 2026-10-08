import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../state/admin_provider.dart';
import '../../theme/admin_theme.dart';

class DoctorScheduleScreen extends StatefulWidget {
  final dynamic doctor;
  
  const DoctorScheduleScreen({super.key, required this.doctor});

  @override
  State<DoctorScheduleScreen> createState() => _DoctorScheduleScreenState();
}

class _DoctorScheduleScreenState extends State<DoctorScheduleScreen> {
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _slots = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchSlots();
  }

  Future<void> _fetchSlots() async {
    setState(() => _isLoading = true);
    final provider = context.read<AdminProvider>();
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final slots = await provider.getSlots(widget.doctor['id'], dateStr);
    
    if (mounted) {
      setState(() {
        _slots = slots;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AdminTheme.primaryColor,
              onPrimary: Colors.white,
              onSurface: AdminTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchSlots();
    }
  }

  Future<void> _blockEntireDay() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AdminTheme.errorColor, size: 24),
            SizedBox(width: 12),
            Text('BLOCK ENTIRE DAY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
          ],
        ),
        content: const Text(
          'This will cancel ALL appointments for this doctor on the selected date. Patients will receive a push notification to reschedule for free.\n\nAre you absolutely sure you want to proceed?',
          style: TextStyle(color: AdminTheme.textPrimary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ABORT', style: TextStyle(color: AdminTheme.textSecondary, letterSpacing: 1.5)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.errorColor, foregroundColor: Colors.white),
            child: const Text('YES, BLOCK DAY', style: TextStyle(letterSpacing: 1.5)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final provider = context.read<AdminProvider>();
    
    final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0, 0);
    final endOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);

    await provider.toggleDoctorUnavailability(
      widget.doctor['id'],
      startOfDay.toIso8601String(),
      endOfDay.toIso8601String(),
      null,
    );
    
    await _fetchSlots();
  }

  Future<void> _toggleSlot(Map<String, dynamic> slot) async {
    final provider = context.read<AdminProvider>();
    final isAvailable = slot['isAvailable'] == true;
    final isBooked = slot['isBooked'] == true;
    final reason = slot['unavailabilityReason'] as String?;
    final uId = slot['unavailabilityId'] as int?;

    if (isBooked) {
      final List<dynamic> bookedAppts = slot['bookedAppointments'] ?? [];
      
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AdminTheme.errorColor, size: 24),
              SizedBox(width: 12),
              Text('CANCEL APPOINTMENT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Marking this slot unavailable will cancel these appointments:'),
                const SizedBox(height: 16),
                ...bookedAppts.map((a) {
                  final mobile = a['patientMobile']?.toString() ?? '';
                  final fee = a['consultationFee']?.toString() ?? '0.00';
                  final doctor = a['doctorName'] ?? widget.doctor['name'];
                  
                  String dateStr = a['appointmentDate'] ?? '';
                  String timeWindow = 'Unknown Time';
                  try {
                    if (a['startTime'] != null && a['endTime'] != null) {
                      final s = DateTime.parse(a['startTime']).toLocal();
                      final e = DateTime.parse(a['endTime']).toLocal();
                      dateStr = DateFormat('MMM dd, yyyy').format(s);
                      timeWindow = '${DateFormat('hh:mm a').format(s)} - ${DateFormat('hh:mm a').format(e)}';
                    }
                  } catch (_) {}

                  return Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AdminTheme.surfaceColor,
                      border: Border.all(color: AdminTheme.borderColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              a['patientName'] ?? 'Unknown Patient', 
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AdminTheme.textPrimary, letterSpacing: -0.5),
                            ),
                            if (a['status'] == 'rescheduled')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'RESCHEDULED',
                                  style: TextStyle(color: Colors.deepOrange, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                              ),
                            if (mobile.isNotEmpty)
                              InkWell(
                                onTap: () async {
                                  final uri = Uri.parse('tel:$mobile');
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AdminTheme.backgroundColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.call_outlined, size: 14, color: AdminTheme.textPrimary),
                                      const SizedBox(width: 4),
                                      Text(mobile, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.textPrimary)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildDialogRow('CODE', a['appointmentCode'] ?? '-'),
                        _buildDialogRow('SERVICE', a['serviceTitle'] ?? '-'),
                        _buildDialogRow('DOCTOR', 'Dr. $doctor'),
                        _buildDialogRow('SCHEDULE', '$dateStr · $timeWindow'),
                        _buildDialogRow('FEE', '₹$fee'),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),
                const Text('Patients will be notified to reschedule. Proceed?', style: TextStyle(color: AdminTheme.errorColor, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ABORT', style: TextStyle(color: AdminTheme.textSecondary, letterSpacing: 1.5)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.errorColor, foregroundColor: Colors.white),
              child: const Text('CANCEL & BLOCK', style: TextStyle(letterSpacing: 1.5)),
            ),
          ],
        ),
      );
      
      if (confirm != true) return;
    }

    if (!isAvailable && reason == 'Break') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('THIS IS A SCHEDULED BREAK.', style: TextStyle(letterSpacing: 1.0))),
      );
      return;
    }

    await provider.toggleDoctorUnavailability(
      widget.doctor['id'],
      slot['startTime'],
      slot['endTime'],
      uId,
    );
    
    _fetchSlots();
  }

  @override
  Widget build(BuildContext context) {
    final isProviderLoading = context.watch<AdminProvider>().isLoading;
    
    return Scaffold(
      backgroundColor: AdminTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('SCHEDULE', style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.w800, fontSize: 16)),
        backgroundColor: AdminTheme.surfaceColor,
        foregroundColor: AdminTheme.textPrimary,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Doctor Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AdminTheme.surfaceColor,
              border: Border(bottom: BorderSide(color: AdminTheme.borderColor)),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline, size: 32, color: AdminTheme.textPrimary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.doctor['name'],
                        style: const TextStyle(color: AdminTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.doctor['specialization'].toUpperCase(),
                        style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Date Selector
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SELECTED DATE', style: TextStyle(color: AdminTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate).toUpperCase(),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary),
                    ),
                  ],
                ),
                OutlinedButton(
                  onPressed: () => _selectDate(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('CHANGE', style: TextStyle(letterSpacing: 1.0)),
                ),
              ],
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Text('Tap a slot to toggle availability.', style: TextStyle(color: AdminTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 12),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: ElevatedButton.icon(
              onPressed: _blockEntireDay,
              icon: const Icon(Icons.block, size: 18),
              label: const Text('BLOCK ENTIRE DAY', style: TextStyle(letterSpacing: 1.0)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.errorColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: _isLoading || isProviderLoading
                ? const Center(child: CircularProgressIndicator(color: AdminTheme.primaryColor))
                : _slots.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.event_busy_outlined, size: 48, color: AdminTheme.borderColor),
                            SizedBox(height: 16),
                            Text('NO SLOTS GENERATED', style: TextStyle(color: AdminTheme.textSecondary, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 2.0,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: _slots.length,
                        itemBuilder: (context, index) {
                          final slot = _slots[index];
                          final isAvailable = slot['isAvailable'] == true;
                          final isBooked = slot['isBooked'] == true;
                          final isPast = slot['isPast'] == true;
                          final hasUnavailability = slot['unavailabilityId'] != null;
                          
                          Color bgColor = AdminTheme.surfaceColor;
                          Color textColor = AdminTheme.textPrimary;
                          Color borderColor = AdminTheme.borderColor;
                          
                          bool isRescheduled = false;
                          if (isBooked && slot['bookedAppointments'] != null) {
                            for (var a in slot['bookedAppointments']) {
                              if (a['status'] == 'rescheduled') {
                                isRescheduled = true;
                                break;
                              }
                            }
                          }

                          if (isBooked) {
                            if (isRescheduled) {
                              bgColor = Colors.deepOrange;
                              textColor = Colors.white;
                              borderColor = Colors.deepOrange;
                            } else {
                              bgColor = AdminTheme.textPrimary;
                              textColor = AdminTheme.surfaceColor;
                              borderColor = AdminTheme.textPrimary;
                            }
                          } else if (hasUnavailability) {
                            bgColor = AdminTheme.errorColor;
                            textColor = Colors.white;
                            borderColor = AdminTheme.errorColor;
                          } else if (!isAvailable) {
                            bgColor = AdminTheme.backgroundColor;
                            textColor = AdminTheme.textSecondary;
                          } else if (isPast) {
                            bgColor = AdminTheme.backgroundColor;
                            textColor = AdminTheme.borderColor;
                          }
                          
                          final startTimeStr = slot['startTime'] as String;
                          final dt = DateTime.parse(startTimeStr).toLocal();
                          final formattedTime = DateFormat('hh:mm a').format(dt);

                          return InkWell(
                            onTap: () => _toggleSlot(slot),
                            borderRadius: BorderRadius.circular(4),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: borderColor, width: 1),
                              ),
                              child: Center(
                                child: Text(
                                  formattedTime,
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    decoration: (isPast || hasUnavailability) ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AdminTheme.textSecondary, letterSpacing: 1.0)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdminTheme.textPrimary)),
          ),
        ],
      ),
    );
  }
}
