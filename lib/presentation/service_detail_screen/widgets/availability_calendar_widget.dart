import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class AvailabilityCalendarWidget extends StatefulWidget {
  final List<Map<String, dynamic>> availabilityData;
  final Function(DateTime, String) onSlotSelected;

  const AvailabilityCalendarWidget({
    Key? key,
    required this.availabilityData,
    required this.onSlotSelected,
  }) : super(key: key);

  @override
  State<AvailabilityCalendarWidget> createState() =>
      _AvailabilityCalendarWidgetState();
}

class _AvailabilityCalendarWidgetState
    extends State<AvailabilityCalendarWidget> {
  int selectedDateIndex = 0;
  String? selectedTimeSlot;

  @override
  Widget build(BuildContext context) {
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
            'Availability',
            style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 2.h),
          _buildDateSelector(),
          SizedBox(height: 2.h),
          _buildTimeSlots(),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return SizedBox(
      height: 10.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widget.availabilityData.length,
        separatorBuilder: (context, index) => SizedBox(width: 2.w),
        itemBuilder: (context, index) {
          final dayData = widget.availabilityData[index];
          final date = DateTime.parse(dayData['date'] as String);
          final dayName = _getDayName(date.weekday);
          final dayNumber = date.day.toString();
          final isSelected = selectedDateIndex == index;
          final isAvailable = (dayData['timeSlots'] as List).isNotEmpty;

          return GestureDetector(
            onTap: isAvailable
                ? () {
                    setState(() {
                      selectedDateIndex = index;
                      selectedTimeSlot = null;
                    });
                  }
                : null,
            child: Container(
              width: 15.w,
              padding: EdgeInsets.symmetric(vertical: 1.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.lightTheme.primaryColor
                    : isAvailable
                        ? AppTheme.lightTheme.colorScheme.surface
                        : AppTheme.lightTheme.colorScheme.surface
                            .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2.w),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.lightTheme.primaryColor
                      : AppTheme.lightTheme.colorScheme.outline
                          .withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayName,
                    style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? Colors.white
                          : isAvailable
                              ? AppTheme.lightTheme.colorScheme.onSurfaceVariant
                              : AppTheme.lightTheme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    dayNumber,
                    style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                      color: isSelected
                          ? Colors.white
                          : isAvailable
                              ? AppTheme.lightTheme.colorScheme.onSurface
                              : AppTheme.lightTheme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeSlots() {
    if (selectedDateIndex >= widget.availabilityData.length) {
      return SizedBox.shrink();
    }

    final selectedDayData = widget.availabilityData[selectedDateIndex];
    final timeSlots = (selectedDayData['timeSlots'] as List).cast<String>();

    if (timeSlots.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: AppTheme.lightTheme.colorScheme.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(2.w),
        ),
        child: Column(
          children: [
            CustomIconWidget(
              iconName: 'schedule',
              color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              size: 32,
            ),
            SizedBox(height: 1.h),
            Text(
              'No available slots',
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Times',
          style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 1.h),
        Wrap(
          spacing: 2.w,
          runSpacing: 1.h,
          children: timeSlots.map((timeSlot) {
            final isSelected = selectedTimeSlot == timeSlot;
            final isJustBooked = _isJustBooked(timeSlot);

            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedTimeSlot = timeSlot;
                });
                final selectedDate =
                    DateTime.parse(selectedDayData['date'] as String);
                widget.onSlotSelected(selectedDate, timeSlot);
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 4.w,
                  vertical: 1.5.h,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.lightTheme.primaryColor
                      : AppTheme.lightTheme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(2.w),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.lightTheme.primaryColor
                        : AppTheme.lightTheme.colorScheme.outline
                            .withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeSlot,
                      style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                        color: isSelected
                            ? Colors.white
                            : AppTheme.lightTheme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isJustBooked) ...[
                      SizedBox(width: 1.w),
                      Container(
                        width: 1.w,
                        height: 1.w,
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  bool _isJustBooked(String timeSlot) {
    // Simulate some slots being just booked for popular times
    final popularSlots = ['10:00 AM', '2:00 PM', '4:00 PM'];
    return popularSlots.contains(timeSlot) && DateTime.now().minute % 3 == 0;
  }
}
