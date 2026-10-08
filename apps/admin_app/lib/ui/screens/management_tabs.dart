import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../state/admin_provider.dart';
import '../../theme/admin_theme.dart';
import 'doctor_form_screen.dart';
import 'service_form_screen.dart';
import 'doctor_schedule_screen.dart';

class ManagementTabs extends StatelessWidget {
  const ManagementTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AdminTheme.borderColor)),
            ),
            child: TabBar(
              labelColor: AdminTheme.textPrimary,
              unselectedLabelColor: AdminTheme.textSecondary,
              indicatorColor: AdminTheme.primaryColor,
              indicatorWeight: 2,
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 1.0),
              tabs: const [
                Tab(text: 'DOCTORS'),
                Tab(text: 'SERVICES'),
                Tab(text: 'PATIENTS'),
                Tab(text: 'DISCOUNT'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _DoctorsTab(),
                _ServicesTab(),
                _PatientsTab(),
                _SettingsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorsTab extends StatefulWidget {
  const _DoctorsTab();

  @override
  State<_DoctorsTab> createState() => _DoctorsTabState();
}

class _DoctorsTabState extends State<_DoctorsTab> {
  List<dynamic> _doctors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    final client = context.read<AdminProvider>().adminApiClient;
    final docs = await client.getDoctors();
    if (mounted) {
      setState(() {
        _doctors = docs;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AdminTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const DoctorFormScreen()));
          if (result == true) _loadDoctors();
        },
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Add Doctor', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_doctors.isEmpty) return _buildEmptyState('No doctors found.', Icons.medical_services_outlined);

    return ListView.separated(
      padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 100),
      itemCount: _doctors.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final doc = _doctors[index];
        return _buildPremiumRow(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(doc['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AdminTheme.textPrimary)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(doc['specialization'] ?? '', style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 14)),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionButton(Icons.calendar_month_outlined, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => DoctorScheduleScreen(doctor: doc)));
                }),
                _buildActionButton(Icons.edit_outlined, () async {
                  final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => DoctorFormScreen(doctor: doc)));
                  if (result == true) _loadDoctors();
                }),
                _buildActionButton(Icons.delete_outline, () async {
                  final confirm = await _confirmDelete(context, 'Doctor');
                  if (confirm == true && mounted) {
                    await context.read<AdminProvider>().deleteDoctor(doc['id']);
                    _loadDoctors();
                  }
                }, isDestructive: true),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ServicesTab extends StatefulWidget {
  const _ServicesTab();

  @override
  State<_ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<_ServicesTab> {
  List<dynamic> _services = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    final client = context.read<AdminProvider>().adminApiClient;
    final serv = await client.getServices();
    if (mounted) {
      setState(() {
        _services = serv;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AdminTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ServiceFormScreen()));
          if (result == true) _loadServices();
        },
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Add Service', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_services.isEmpty) return _buildEmptyState('No services found.', Icons.local_hospital_outlined);

    return ListView.separated(
      padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 100),
      itemCount: _services.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final serv = _services[index];
        return _buildPremiumRow(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(serv['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AdminTheme.textPrimary)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text('₹${serv['base_fee']}', style: const TextStyle(color: AdminTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 14)),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionButton(Icons.edit_outlined, () async {
                  final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceFormScreen(service: serv)));
                  if (result == true) _loadServices();
                }),
                _buildActionButton(Icons.delete_outline, () async {
                  final confirm = await _confirmDelete(context, 'Service');
                  if (confirm == true && mounted) {
                    await context.read<AdminProvider>().deleteService(serv['id']);
                    _loadServices();
                  }
                }, isDestructive: true),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PatientsTab extends StatefulWidget {
  const _PatientsTab();

  @override
  State<_PatientsTab> createState() => _PatientsTabState();
}

class _PatientsTabState extends State<_PatientsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchPatients();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final patients = provider.patients;
    
    if (provider.isLoading) return const Center(child: CircularProgressIndicator());
    if (patients.isEmpty) return _buildEmptyState('No patients found.', Icons.people_outline);

    return ListView.separated(
      padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 100),
      itemCount: patients.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final p = patients[index];
        final mobile = p['mobile_number']?.toString().isNotEmpty == true ? p['mobile_number'] : 'N/A';
        final age = p['age'] != null ? '${p['age']}y' : 'N/A';
        final code = p['latest_appointment_code'] ?? 'No Appts';
        final service = p['latest_service_title'] ?? '';
        
        return _buildPremiumRow(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) {
                  return DraggableScrollableSheet(
                    initialChildSize: 0.85,
                    maxChildSize: 0.95,
                    expand: false,
                    builder: (context, scrollController) {
                      return Container(
                        decoration: const BoxDecoration(
                          color: AdminTheme.surfaceColor,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(0)), // Sharp edges
                        ),
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('PATIENT DOSSIER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AdminTheme.textSecondary)),
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(p['full_name'] ?? 'Unknown', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary, letterSpacing: -1.0)),
                              const SizedBox(height: 8),
                              Text('ID: ${p['patient_id'] ?? 'N/A'}', style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
                              
                              const SizedBox(height: 48),
                              const _SectionHeader('CONTACT INFORMATION'),
                              const SizedBox(height: 16),
                              _buildClickablePhoneRow('MOBILE', p['mobile_number']),
                              _DetailRow('EMAIL', p['email']),
                              _DetailRow('EMERGENCY CONTACT', p['emergency_contact']),
                              _DetailRow('ADDRESS', p['address']),
                              _DetailRow('CITY', p['city']),
                              _DetailRow('PINCODE', p['pincode']),
                              
                              const SizedBox(height: 48),
                              const _SectionHeader('MEDICAL DETAILS'),
                              const SizedBox(height: 16),
                              _DetailRow('AGE', p['age']?.toString() != null ? '${p['age']} years' : null),
                              _DetailRow('GENDER', p['gender']),
                              _DetailRow('BLOOD GROUP', p['blood_group']),
                              _DetailRow('MEDICAL NOTES', p['medical_notes']),
                              
                              const SizedBox(height: 48),
                              const _SectionHeader('LATEST APPOINTMENT'),
                              const SizedBox(height: 16),
                              _DetailRow('CODE', p['latest_appointment_code']),
                              _DetailRow('SERVICE', p['latest_service_title']),
                              _DetailRow('DOCTOR', p['latest_doctor_name']),
                              Builder(
                                builder: (context) {
                                  if (p['latest_appointment_date'] == null) return const SizedBox.shrink();
                                  String timeWindow = p['latest_appointment_date'];
                                  try {
                                    final s = DateTime.parse(p['latest_start_time']).toLocal();
                                    final e = DateTime.parse(p['latest_end_time']).toLocal();
                                    timeWindow = '${DateFormat('MMM dd, yyyy').format(s)} · ${DateFormat('hh:mm a').format(s)} - ${DateFormat('hh:mm a').format(e)}';
                                  } catch (_) {}
                                  return _DetailRow('SCHEDULE', timeWindow);
                                }
                              ),
                              if (p['latest_service_fee'] != null)
                                _DetailRow('FEE', '₹${p['latest_service_fee']}'),
                                
                              const SizedBox(height: 64),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(p['full_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AdminTheme.textPrimary)),
                      Text(age, style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 14, color: AdminTheme.textSecondary),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: mobile != 'N/A' ? () => launchUrl(Uri.parse('tel:$mobile')) : null,
                        child: Text(mobile, style: TextStyle(color: mobile != 'N/A' ? AdminTheme.textPrimary : AdminTheme.textSecondary, fontSize: 13, decoration: mobile != 'N/A' ? TextDecoration.underline : null, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                  if (code != 'No Appts') ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('LATEST: $code', style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                        if (service.isNotEmpty)
                          Text(service, style: const TextStyle(color: AdminTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          )
        );
      },
    );
  }
}

// Helpers

Widget _buildEmptyState(String message, IconData icon) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: AdminTheme.borderColor),
        const SizedBox(height: 16),
        Text(message, style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 15, fontWeight: FontWeight.w500)),
      ],
    ),
  );
}

Widget _buildPremiumRow({required Widget child}) {
  return Container(
    decoration: BoxDecoration(
      color: AdminTheme.surfaceColor,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AdminTheme.borderColor, width: 1),
    ),
    child: Material(
      color: Colors.transparent,
      child: child,
    ),
  );
}

Widget _buildActionButton(IconData icon, VoidCallback onTap, {bool isDestructive = false}) {
  return IconButton(
    icon: Icon(icon, color: isDestructive ? AdminTheme.errorColor : AdminTheme.textSecondary, size: 20),
    onPressed: onTap,
    splashRadius: 20,
  );
}

Future<bool?> _confirmDelete(BuildContext context, String entityName) {
  return showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Sharp
      title: Text('Delete $entityName', style: const TextStyle(fontWeight: FontWeight.w700, color: AdminTheme.textPrimary)),
      content: Text('Are you sure you want to delete this $entityName? This action cannot be undone.', style: const TextStyle(color: AdminTheme.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel', style: TextStyle(color: AdminTheme.textSecondary))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.errorColor, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(c, true), 
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AdminTheme.borderColor)),
      ),
      padding: const EdgeInsets.only(bottom: 8),
      width: double.infinity,
      child: Text(
        title, 
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AdminTheme.textSecondary)
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String? value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          ),
          Expanded(
            child: Text(value!, style: const TextStyle(fontWeight: FontWeight.w500, color: AdminTheme.textPrimary, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

Widget _buildClickablePhoneRow(String label, String? value) {
  if (value == null || value.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(bottom: 16.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(label, style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => launchUrl(Uri.parse('tel:$value')),
            child: Row(
              children: [
                Text(value, style: const TextStyle(fontWeight: FontWeight.w500, color: AdminTheme.textPrimary, fontSize: 14, decoration: TextDecoration.underline)),
                const SizedBox(width: 8),
                const Icon(Icons.call_outlined, size: 14, color: AdminTheme.textPrimary),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _SettingsTab extends StatefulWidget {
  const _SettingsTab();

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  bool _isLoading = true;
  bool _isActive = true;
  int _discountPercentage = 30;
  int _validityDays = 30;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final client = context.read<AdminProvider>().adminApiClient;
    final settings = await client.getDiscountSettings();
    if (mounted && settings != null) {
      setState(() {
        _isActive = settings['is_active'] ?? true;
        _discountPercentage = settings['discount_percentage'] ?? 30;
        _validityDays = settings['validity_days'] ?? 30;
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    final client = context.read<AdminProvider>().adminApiClient;
    final success = await client.updateDiscountSettings({
      'is_active': _isActive,
      'discount_percentage': _discountPercentage,
      'validity_days': _validityDays,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Settings saved successfully' : 'Failed to save settings'),
        backgroundColor: success ? Colors.green : Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Discount Configurations', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AdminTheme.textPrimary)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AdminTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                title: const Text('Enable 30-Day Follow-Up Discount', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Patients get a discount on their 2nd visit within the validity period.'),
                value: _isActive,
                activeColor: AdminTheme.primaryColor,
                onChanged: (val) => setState(() => _isActive = val),
              ),
              const Divider(height: 32),
              const Text('Discount Percentage (%)', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: _discountPercentage.toString(),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (val) => _discountPercentage = int.tryParse(val) ?? _discountPercentage,
              ),
              const SizedBox(height: 24),
              const Text('Validity Window (Days)', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: _validityDays.toString(),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (val) => _validityDays = int.tryParse(val) ?? _validityDays,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _saveSettings,
                  child: const Text('SAVE SETTINGS', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.0)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
