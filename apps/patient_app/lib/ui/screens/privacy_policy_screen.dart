import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy for Wadgaonkar Eye Hospital App',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Effective Date: August 20, 2026',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Welcome to the Wadgaonkar Eye Hospital mobile application. Your privacy is of paramount importance to us. This Privacy Policy explains how we collect, use, and safeguard your health and personal information.',
            ),
            const SizedBox(height: 24),
            Text(
              '1. Information We Collect',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'We collect information you provide directly to us when you create an account, book an appointment, or process a payment. This includes your name, mobile number, email address, appointment details, and related health information necessary for clinical purposes.',
            ),
            const SizedBox(height: 24),
            Text(
              '2. How We Use Your Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'We use your data strictly to facilitate hospital services, schedule appointments, send you notifications (like late arrivals and doctor unavailability), and process secure payments. Your data is not sold or shared with third parties for marketing purposes.',
            ),
            const SizedBox(height: 24),
            Text(
              '3. Data Storage and Security',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your information is securely stored on our servers and protected using industry-standard encryption. Access to your health data is restricted only to authorized hospital staff who require it to provide care.',
            ),
            const SizedBox(height: 24),
            Text(
              '4. Your Rights',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'You have the right to view, edit, or request deletion of your account and personal data from within the app settings or by contacting the hospital administration directly.',
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'For any privacy-related queries, please contact the hospital reception.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
