import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../state/admin_provider.dart';
import '../../theme/admin_theme.dart';

class DoctorFormScreen extends StatefulWidget {
  final Map<String, dynamic>? doctor;

  const DoctorFormScreen({super.key, this.doctor});

  @override
  State<DoctorFormScreen> createState() => _DoctorFormScreenState();
}

enum TimePickerTarget { shiftStart, shiftEnd, breakStart, breakEnd }

class _DoctorFormScreenState extends State<DoctorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late final TextEditingController _idController;
  late final TextEditingController _nameController;
  late final TextEditingController _qualificationController;
  late final TextEditingController _specializationController;
  
  late final TextEditingController _shiftStartController;
  late final TextEditingController _shiftEndController;
  late final TextEditingController _breakStartController;
  late final TextEditingController _breakEndController;

  String _shiftStart24 = '09:00';
  String _shiftEnd24 = '19:30';
  String _breakStart24 = '13:30';
  String _breakEnd24 = '16:00';

  bool get isUpdate => widget.doctor != null;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(text: widget.doctor?['id'] ?? '');
    _nameController = TextEditingController(text: widget.doctor?['name'] ?? '');
    _qualificationController = TextEditingController(text: widget.doctor?['qualification'] ?? '');
    _specializationController = TextEditingController(text: widget.doctor?['specialization'] ?? '');
    
    _shiftStart24 = widget.doctor?['shift_start_time'] ?? '09:00';
    _shiftEnd24 = widget.doctor?['shift_end_time'] ?? '19:30';
    _breakStart24 = widget.doctor?['break_start_time'] ?? '13:30';
    _breakEnd24 = widget.doctor?['break_end_time'] ?? '16:00';
    
    _shiftStartController = TextEditingController(text: _format12Hour(_shiftStart24));
    _shiftEndController = TextEditingController(text: _format12Hour(_shiftEnd24));
    _breakStartController = TextEditingController(text: _format12Hour(_breakStart24));
    _breakEndController = TextEditingController(text: _format12Hour(_breakEnd24));
  }

  String _format12Hour(String time24) {
    try {
      final parts = time24.split(':');
      final tod = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return time24;
    }
  }

  Future<void> _pickTime(TimePickerTarget target) async {
    String currentStr = '';
    switch (target) {
      case TimePickerTarget.shiftStart: currentStr = _shiftStart24; break;
      case TimePickerTarget.shiftEnd: currentStr = _shiftEnd24; break;
      case TimePickerTarget.breakStart: currentStr = _breakStart24; break;
      case TimePickerTarget.breakEnd: currentStr = _breakEnd24; break;
    }
    
    TimeOfDay initial = const TimeOfDay(hour: 9, minute: 0);
    try {
      final parts = currentStr.split(':');
      initial = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {}

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final hourStr = picked.hour.toString().padLeft(2, '0');
      final minuteStr = picked.minute.toString().padLeft(2, '0');
      final val24 = '$hourStr:$minuteStr';
      setState(() {
        switch (target) {
          case TimePickerTarget.shiftStart:
            _shiftStart24 = val24;
            _shiftStartController.text = _format12Hour(val24);
            break;
          case TimePickerTarget.shiftEnd:
            _shiftEnd24 = val24;
            _shiftEndController.text = _format12Hour(val24);
            break;
          case TimePickerTarget.breakStart:
            _breakStart24 = val24;
            _breakStartController.text = _format12Hour(val24);
            break;
          case TimePickerTarget.breakEnd:
            _breakEnd24 = val24;
            _breakEndController.text = _format12Hour(val24);
            break;
        }
      });
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _qualificationController.dispose();
    _specializationController.dispose();
    _shiftStartController.dispose();
    _shiftEndController.dispose();
    _breakStartController.dispose();
    _breakEndController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final doctorId = isUpdate ? _idController.text.trim() : 'doc_${DateTime.now().millisecondsSinceEpoch}';
    
    final data = {
      'name': _nameController.text.trim(),
      'qualification': _qualificationController.text.trim(),
      'specialization': _specializationController.text.trim(),
      'shift_start_time': _shiftStart24,
      'shift_end_time': _shiftEnd24,
      'break_start_time': _breakStart24,
      'break_end_time': _breakEnd24,
    };

    try {
      await context.read<AdminProvider>().saveDoctor(doctorId, data, isUpdate: isUpdate);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isUpdate ? 'DOCTOR UPDATED' : 'DOCTOR CREATED',
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
          isUpdate ? 'EDIT DOCTOR' : 'ADD DOCTOR',
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
                const Icon(Icons.person_add_alt_1_outlined, size: 48, color: AdminTheme.textPrimary),
                const SizedBox(height: 24),
                const Text(
                  'DOCTOR DETAILS',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.textSecondary, letterSpacing: 2.0),
                ),
                const SizedBox(height: 40),
                if (isUpdate) ...[
                  TextFormField(
                    controller: _idController,
                    decoration: const InputDecoration(
                      labelText: 'DOCTOR ID',
                      enabled: false,
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                ],
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'FULL NAME',
                    hintText: 'e.g. Dr. Anand',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _qualificationController,
                  decoration: const InputDecoration(
                    labelText: 'QUALIFICATION / DEGREE',
                    hintText: 'e.g. MBBS, MS (Ophthalmology)',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _specializationController,
                  decoration: const InputDecoration(
                    labelText: 'SPECIALIZATION',
                    hintText: 'e.g. Cataract & Refractive Surgeon',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _shiftStartController,
                        readOnly: true,
                        onTap: () => _pickTime(TimePickerTarget.shiftStart),
                        decoration: const InputDecoration(
                          labelText: 'SHIFT START',
                          suffixIcon: Icon(Icons.wb_sunny_outlined),
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _shiftEndController,
                        readOnly: true,
                        onTap: () => _pickTime(TimePickerTarget.shiftEnd),
                        decoration: const InputDecoration(
                          labelText: 'SHIFT END',
                          suffixIcon: Icon(Icons.nightlight_round),
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _breakStartController,
                        readOnly: true,
                        onTap: () => _pickTime(TimePickerTarget.breakStart),
                        decoration: const InputDecoration(
                          labelText: 'BREAK START',
                          suffixIcon: Icon(Icons.fastfood_outlined),
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _breakEndController,
                        readOnly: true,
                        onTap: () => _pickTime(TimePickerTarget.breakEnd),
                        decoration: const InputDecoration(
                          labelText: 'BREAK END',
                          suffixIcon: Icon(Icons.access_time_rounded),
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    child: isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            isUpdate ? 'SAVE CHANGES' : 'CREATE DOCTOR',
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
