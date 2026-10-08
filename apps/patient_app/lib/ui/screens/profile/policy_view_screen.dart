import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:weh_shared/weh_shared.dart';

class PolicyViewScreen extends StatelessWidget {
  final String title;
  final String markdownContent;

  const PolicyViewScreen({
    super.key,
    required this.title,
    required this.markdownContent,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
        elevation: 0,
        backgroundColor: AppColors.surface,
      ),
      body: SafeArea(
        child: Markdown(
          data: markdownContent,
          styleSheet: MarkdownStyleSheet(
            h1: AppTypography.headlineMedium.copyWith(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            h2: AppTypography.titleLarge.copyWith(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary, height: 2.0),
            p: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, height: 1.5),
            listBullet: TextStyle(color: AppColors.primary),
            strong: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            a: TextStyle(color: Colors.blue.shade700, decoration: TextDecoration.underline),
          ),
        ),
      ),
    );
  }
}
