import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/admin_provider.dart';

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
            onPressed: () {
              // Navigate to Edit screen (TODO)
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
            onPressed: () {
              // Navigate to Edit screen (TODO)
            },
          ),
        );
      },
    );
  }
}

class _PatientsTab extends StatelessWidget {
  const _PatientsTab();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Patient search and history goes here'));
  }
}
