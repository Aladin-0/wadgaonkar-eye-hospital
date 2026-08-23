import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/admin_provider.dart';

class ServiceFormScreen extends StatefulWidget {
  final Map<String, dynamic>? service;

  const ServiceFormScreen({super.key, this.service});

  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late final TextEditingController _idController;
  late final TextEditingController _titleController;
  late final TextEditingController _baseFeeController;
  late final TextEditingController _descriptionController;

  bool get isUpdate => widget.service != null;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(text: widget.service?['id'] ?? '');
    _titleController = TextEditingController(text: widget.service?['title'] ?? '');
    _baseFeeController = TextEditingController(text: widget.service?['base_fee']?.toString() ?? '0.00');
    _descriptionController = TextEditingController(text: widget.service?['description'] ?? '');
  }

  @override
  void dispose() {
    _idController.dispose();
    _titleController.dispose();
    _baseFeeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final data = {
      'title': _titleController.text.trim(),
      'base_fee': _baseFeeController.text.trim(),
      'description': _descriptionController.text.trim(),
    };

    try {
      await context.read<AdminProvider>().saveService(_idController.text.trim(), data, isUpdate: isUpdate);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service saved successfully!')),
        );
        Navigator.pop(context, true);
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
        title: Text(isUpdate ? 'Edit Service' : 'Add Service'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _idController,
                decoration: const InputDecoration(labelText: 'Service ID (e.g. srv_consultation)'),
                enabled: !isUpdate,
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _baseFeeController,
                decoration: const InputDecoration(labelText: 'Base Fee'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description (Optional)'),
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: isLoading ? null : _submit,
                child: isLoading
                    ? const CircularProgressIndicator()
                    : Text(isUpdate ? 'Save Changes' : 'Create Service'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
