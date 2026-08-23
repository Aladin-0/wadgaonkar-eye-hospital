import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/admin_provider.dart';
import 'doctor_form_screen.dart';
import 'service_form_screen.dart';

class ManagementTabs extends StatelessWidget {
  const ManagementTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: const TabBar(
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.black,
          tabs: [
            Tab(text: 'Doctors'),
            Tab(text: 'Services'),
            Tab(text: 'Patients'),
          ],
        ),
        body: const TabBarView(
          children: [
            _DoctorsTab(),
            _ServicesTab(),
            _PatientsTab(),
          ],
        ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const DoctorFormScreen()));
          if (result == true) _loadDoctors();
        },
        child: const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_doctors.isEmpty) return const Center(child: Text('No doctors found.'));

    return ListView.builder(
      itemCount: _doctors.length,
      itemBuilder: (context, index) {
        final doc = _doctors[index];
        return ListTile(
          title: Text(doc['name'] ?? ''),
          subtitle: Text(doc['specialization'] ?? ''),
          trailing: IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => DoctorFormScreen(doctor: doc)));
              if (result == true) _loadDoctors();
            },
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ServiceFormScreen()));
          if (result == true) _loadServices();
        },
        child: const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_services.isEmpty) return const Center(child: Text('No services found.'));

    return ListView.builder(
      itemCount: _services.length,
      itemBuilder: (context, index) {
        final serv = _services[index];
        return ListTile(
          title: Text(serv['title'] ?? ''),
          subtitle: Text('Fee: ₹${serv['base_fee']}'),
          trailing: IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceFormScreen(service: serv)));
              if (result == true) _loadServices();
            },
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
    if (patients.isEmpty) return const Center(child: Text('No patients found.'));

    return ListView.builder(
      itemCount: patients.length,
      itemBuilder: (context, index) {
        final p = patients[index];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(p['full_name'] ?? 'Unknown'),
          subtitle: Text('Mobile: ${p['mobile_number']} | Age: ${p['age'] ?? 'N/A'}'),
        );
      },
    );
  }
}
