import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/admin_provider.dart';

class DoctorFormScreen extends StatefulWidget {
  final Map<String, dynamic>? doctor;

  const DoctorFormScreen({super.key, this.doctor});

  @override
  State<DoctorFormScreen> createState() => _DoctorFormScreenState();
}

class _DoctorFormScreenState extends State<DoctorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late final TextEditingController _idController;
  late final TextEditingController _nameController;
  late final TextEditingController _specializationController;

  bool get isUpdate => widget.doctor != null;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(text: widget.doctor?['id'] ?? '');
    _nameController = TextEditingController(text: widget.doctor?['name'] ?? '');
    _specializationController = TextEditingController(text: widget.doctor?['specialization'] ?? '');
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _specializationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final data = {
      'name': _nameController.text.trim(),
      'specialization': _specializationController.text.trim(),
    };

    try {
      await context.read<AdminProvider>().saveDoctor(_idController.text.trim(), data, isUpdate: isUpdate);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Doctor saved successfully!')),
        );
        Navigator.pop(context, true); // Return true to signal refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AdminProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(isUpdate ? 'Edit Doctor' : 'Add Doctor'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _idController,
                decoration: const InputDecoration(labelText: 'Doctor ID (e.g. doc_anand)'),
                enabled: !isUpdate, // Cannot change ID on update
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _specializationController,
                decoration: const InputDecoration(labelText: 'Specialization'),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: isLoading ? null : _submit,
                child: isLoading
                    ? const CircularProgressIndicator()
                    : Text(isUpdate ? 'Save Changes' : 'Create Doctor'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
