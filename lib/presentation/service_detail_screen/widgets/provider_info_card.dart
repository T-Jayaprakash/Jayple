import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class ProviderInfoCard extends StatelessWidget {
  final Map<String, dynamic> providerData;
  final VoidCallback onReviewsTap;

  const ProviderInfoCard({
    Key? key,
    required this.providerData,
    required this.onReviewsTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final rating = (providerData['rating'] as num?)?.toDouble() ?? 0.0;
    final reviewCount = providerData['reviewCount'] as int? ?? 0;
    final name = providerData['name'] as String? ?? 'Unknown Provider';
    final type = providerData['type'] as String? ?? 'Service Provider';
    final isVerified = providerData['isVerified'] as bool? ?? false;

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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: AppTheme.lightTheme.textTheme.titleLarge
                                ?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVerified) ...[
                          SizedBox(width: 2.w),
                          CustomIconWidget(
                            iconName: 'verified',
                            color: AppTheme.lightTheme.primaryColor,
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 0.5.h),
                    Text(
                      type,
                      style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          GestureDetector(
            onTap: onReviewsTap,
            child: Row(
              children: [
                Row(
                  children: List.generate(5, (index) {
                    return CustomIconWidget(
                      iconName: index < rating.floor() ? 'star' : 'star_border',
                      color: index < rating.floor()
                          ? Colors.amber
                          : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                      size: 18,
                    );
                  }),
                ),
                SizedBox(width: 2.w),
                Text(
                  rating.toStringAsFixed(1),
                  style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 2.w),
                Text(
                  '($reviewCount reviews)',
                  style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Spacer(),
                CustomIconWidget(
                  iconName: 'chevron_right',
                  color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
