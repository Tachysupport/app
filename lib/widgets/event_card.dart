import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/calendar_event.dart';

class EventCard extends StatelessWidget {
  final CalendarEvent event;
  final bool isCompact;
  final VoidCallback? onTap;

  const EventCard({
    super.key,
    required this.event,
    this.isCompact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = event.isCompleted;
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: isCompleted
            ? event.color.withOpacity(0.12)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: event.color.withOpacity(0.7), width: 2),
        boxShadow: [
          BoxShadow(
            color: event.color.withOpacity(0.08),
            blurRadius: 8.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14.r),
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left accent bar
                  Container(
                    width: 6.w,
                    height: isCompact ? 56.h : 88.h,
                    decoration: BoxDecoration(
                      color: event.color,
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(14.r),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            event.title,
                                            style: TextStyle(
                                              fontSize: 16.sp,
                                              fontWeight: FontWeight.w600,
                                              color: isCompleted
                                                  ? event.color
                                                  : Theme.of(context).colorScheme.onSurface,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isCompleted)
                                          Padding(
                                            padding: EdgeInsets.only(left: 8.w),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: event.color,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: event.color.withOpacity(0.3),
                                                    blurRadius: 8,
                                                    offset: Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Icon(
                                                Icons.celebration,
                                                color: Colors.white,
                                                size: 20.w,
                                              ),
                                            ),
                                          ),
                                        if (isCompleted)
                                          Padding(
                                            padding: EdgeInsets.only(left: 4.w),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                              decoration: BoxDecoration(
                                                color: event.color.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(8.r),
                                              ),
                                              child: Text(
                                                'Completed',
                                                style: TextStyle(
                                                  fontSize: 10.sp,
                                                  color: event.color,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (event.isGoogleCalendarEvent)
                                      Container(
                                        padding: EdgeInsets.all(4.w),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            4.r,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.link,
                                          size: 12.w,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      ),
                                    if (event.isAllDay)
                                      Container(
                                        margin: EdgeInsets.only(left: 4.w),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 6.w,
                                          vertical: 2.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(
                                            4.r,
                                          ),
                                        ),
                                        child: Text(
                                          'All-day',
                                          style: TextStyle(
                                            fontSize: 10.sp,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ),
                                    if (event.attachment.isNotEmpty)
                                      Padding(
                                        padding: EdgeInsets.only(left: 4.w),
                                        child: Icon(
                                          Icons.attach_file,
                                          size: 14.w,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14.w,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.6),
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                event.timeRange,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: isCompleted
                                      ? event.color.withOpacity(0.7)
                                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                              if (event.recurrence != 'Does not repeat')
                                Padding(
                                  padding: EdgeInsets.only(left: 8.w),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.repeat,
                                        size: 12.w,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                      SizedBox(width: 2.w),
                                      Text(
                                        event.recurrence,
                                        style: TextStyle(
                                          fontSize: 10.sp,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          if (!isCompact && event.description.isNotEmpty) ...[
                            SizedBox(height: 8.h),
                            Text(
                              event.description,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: isCompleted
                                    ? event.color
                                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                                fontStyle: isCompleted ? FontStyle.italic : FontStyle.normal,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (!isCompact && event.location.isNotEmpty) ...[
                            SizedBox(height: 8.h),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 14.w,
                                  color: isCompleted
                                      ? event.color
                                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                                SizedBox(width: 4.w),
                                Expanded(
                                  child: Text(
                                    event.location,
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: isCompleted
                                          ? event.color
                                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Creative overlay for completed events
              if (isCompleted)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: 0.18,
                      duration: Duration(milliseconds: 500),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [event.color, Colors.white],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
