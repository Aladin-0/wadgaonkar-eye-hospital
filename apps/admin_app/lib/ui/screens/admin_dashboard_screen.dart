import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/admin_provider.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
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
    final appts = provider.todayAppointments;

    // Filter to today's appointments only
    final now = DateTime.now();
    final todaysAppts = appts.where((a) {
      if (a['appointment_date'] == null) return false;
      try {
        final date = DateTime.parse(a['appointment_date']);
        return date.year == now.year && date.month == now.month && date.day == now.day;
      } catch (_) {
        return false;
      }
    }).toList();

    return RefreshIndicator(
      onRefresh: provider.fetchDashboardData,
      child: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.error != null
              ? Center(child: Text(provider.error!, style: const TextStyle(color: Colors.red)))
              : todaysAppts.isEmpty
                  ? const Center(child: Text("No appointments today."))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: todaysAppts.length,
                      itemBuilder: (context, index) {
                        final appt = todaysAppts[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getStatusColor(appt['booking_status']),
                              child: const Icon(Icons.person, color: Colors.white),
                            ),
                            title: Text(appt['patient_name'] ?? 'Unknown Patient'),
                            subtitle: Text('${appt['slot_start_time']} - ${appt['booking_status']}'),
                            trailing: Text(appt['appointment_code'] ?? ''),
                          ),
                        );
                      },
                    ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'confirmed': return Colors.blue;
      case 'checkedIn': return Colors.green;
      case 'completed': return Colors.grey;
      case 'cancelled': return Colors.red;
      case 'noShow': return Colors.orange;
      case 'gracePeriod': return Colors.amber;
      default: return Colors.grey;
    }
  }
}
