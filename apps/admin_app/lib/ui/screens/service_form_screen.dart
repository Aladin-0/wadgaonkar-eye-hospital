import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/admin_provider.dart';
import '../../theme/admin_theme.dart';

class ServiceFormScreen extends StatefulWidget {
  final Map<String, dynamic>? service;

  const ServiceFormScreen({super.key, this.service});

  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late final TextEditingController _titleController;
  late final TextEditingController _baseFeeController;
  late final TextEditingController _descriptionController;

  bool get isUpdate => widget.service != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.service?['title'] ?? '');
    _baseFeeController = TextEditingController(text: widget.service?['base_fee']?.toString() ?? '');
    _descriptionController = TextEditingController(text: widget.service?['description'] ?? '');
  }

  @override
  void dispose() {
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

    final id = widget.service?['id'] ?? '';
    try {
      await context.read<AdminProvider>().saveService(id, data, isUpdate: isUpdate);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isUpdate ? 'SERVICE UPDATED' : 'SERVICE CREATED',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0),
            ),
            backgroundColor: AdminTheme.primaryColor,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ERROR: $e'.toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0),
            ),
            backgroundColor: AdminTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AdminProvider>().isLoading;

    return Scaffold(
      backgroundColor: AdminTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          isUpdate ? 'EDIT SERVICE' : 'ADD SERVICE',
          style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5, fontSize: 16),
        ),
        backgroundColor: AdminTheme.surfaceColor,
        foregroundColor: AdminTheme.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: AdminTheme.surfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AdminTheme.borderColor),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.medical_services_outlined, size: 48, color: AdminTheme.textPrimary),
                const SizedBox(height: 24),
                const Text(
                  'SERVICE DETAILS',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.textSecondary, letterSpacing: 2.0),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'TITLE',
                    hintText: 'e.g. Regular Checkup',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _baseFeeController,
                  decoration: const InputDecoration(
                    labelText: 'BASE FEE (₹)',
                    hintText: 'e.g. 500',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'DESCRIPTION (OPTIONAL)',
                    hintText: 'Additional details about the service',
                    alignLabelWithHint: true,
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                  maxLines: 3,
                ),
                const SizedBox(height: 48),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    child: isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            isUpdate ? 'SAVE CHANGES' : 'CREATE SERVICE',
                            style: const TextStyle(letterSpacing: 2.0),
                          ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
