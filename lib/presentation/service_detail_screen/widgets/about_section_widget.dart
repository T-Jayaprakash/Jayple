import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class AboutSectionWidget extends StatelessWidget {
  final Map<String, dynamic> aboutData;

  const AboutSectionWidget({
    Key? key,
    required this.aboutData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bio = aboutData['bio'] as String? ?? '';
    final specialties =
        (aboutData['specialties'] as List?)?.cast<String>() ?? [];
    final experience = aboutData['experience'] as String? ?? '';
    final certifications =
        (aboutData['certifications'] as List?)?.cast<String>() ?? [];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
        borderRadius: BorderRadius.circular(3.w),
        boxShadow: [
          BoxShadow(
            color: AppTheme.lightTheme.colorScheme.shadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About',
            style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (bio.isNotEmpty) ...[
            SizedBox(height: 2.h),
            Text(
              bio,
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
          if (experience.isNotEmpty) ...[
            SizedBox(height: 2.h),
            _InfoRow(
              icon: 'work',
              title: 'Experience',
              value: experience,
            ),
          ],
          if (specialties.isNotEmpty) ...[
            SizedBox(height: 2.h),
            _InfoRow(
              icon: 'star',
              title: 'Specialties',
              value: specialties.join(', '),
            ),
          ],
          if (certifications.isNotEmpty) ...[
            SizedBox(height: 2.h),
            _InfoRow(
              icon: 'verified',
              title: 'Certifications',
              value: certifications.join(', '),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String icon;
  final String title;
  final String value;

  const _InfoRow({
    Key? key,
    required this.icon,
    required this.title,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomIconWidget(
          iconName: icon,
          color: AppTheme.lightTheme.primaryColor,
          size: 20,
        ),
        SizedBox(width: 3.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 0.5.h),
              Text(
                value,
                style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
