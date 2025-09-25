import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/scheduler.dart';
import '../providers/calendar_provider.dart';
import '../services/notification_service.dart';
import '../models/calendar_event.dart';
import '../widgets/event_card.dart';
import '../widgets/event_details_dialog.dart';
import './new_event.dart';
import '../constants/app_colors.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late PageController _pageController;
  late DateTime _focusedDate;
  bool _showCalendar = true;
  late DateTime _now;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _ticker = Ticker((_) {
      final now = DateTime.now();
      if (_now.minute != now.minute) {
        setState(() => _now = now);
      }
    })..start();
    _focusedDate = DateTime.now();
    _pageController = PageController(initialPage: 1000); // Start in the middle
  }

  @override
  void dispose() {
    _ticker.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Calendar',
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600),
            ),
            Text(
              DateFormat('EEEE, MMMM d, h:mm a').format(_now),
              style: TextStyle(
                fontSize: 12.sp,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showCalendar ? Icons.calendar_view_month : Icons.calendar_today,
              size: 24.w,
            ),
            onPressed: () {
              setState(() {
                _showCalendar = !_showCalendar;
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.today, size: 24.w),
            onPressed: () {
              setState(() {
                _focusedDate = DateTime.now();
              });
              context.read<CalendarProvider>().setSelectedDate(DateTime.now());
            },
          ),
          IconButton(
            icon: Icon(Icons.add, size: 24.w),
            onPressed: () {
              Navigator.pushNamed(context, '/new_event');
            },
          ),
        ],
      ),
      body: Consumer<CalendarProvider>(
        builder: (context, calendarProvider, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_showCalendar) ...[
                      _buildCalendarHeader(context, calendarProvider),
                      _buildCalendarView(context, calendarProvider),
                    ],
                    SizedBox(
                      height: constraints.maxHeight * 0.6,
                      child: _buildEventsList(context, calendarProvider),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCalendarHeader(
    BuildContext context,
    CalendarProvider calendarProvider,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 16.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  AppColors.primaryDarkBlue,
                  AppColors.accentTeal.withOpacity(0.2),
                ]
              : [
                  AppColors.primaryLightBlue,
                  AppColors.accentLightTeal.withOpacity(0.2),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.12)
                : Colors.blue.withOpacity(0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  Icons.chevron_left,
                  size: 24.w,
                  color: AppColors.primaryBlue,
                ),
                onPressed: () {
                  setState(() {
                    if (calendarProvider.viewType == CalendarViewType.week) {
                      _focusedDate = _focusedDate.subtract(
                        const Duration(days: 7),
                      );
                    } else {
                      _focusedDate = DateTime(
                        _focusedDate.year,
                        _focusedDate.month - 1,
                        _focusedDate.day,
                      );
                    }
                  });
                  calendarProvider.setSelectedDate(_focusedDate);
                },
              ),
              Text(
                DateFormat('MMMM yyyy').format(_focusedDate),
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                  letterSpacing: 1.2,
                  shadows: [
                    Shadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.18)
                          : Colors.blue.withOpacity(0.12),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.chevron_right,
                  size: 24.w,
                  color: AppColors.primaryBlue,
                ),
                onPressed: () {
                  setState(() {
                    if (calendarProvider.viewType == CalendarViewType.week) {
                      _focusedDate = _focusedDate.add(const Duration(days: 7));
                    } else {
                      _focusedDate = DateTime(
                        _focusedDate.year,
                        _focusedDate.month + 1,
                        _focusedDate.day,
                      );
                    }
                  });
                  calendarProvider.setSelectedDate(_focusedDate);
                },
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _buildViewTypeSelector(context, calendarProvider),
        ],
      ),
    );
  }

  Widget _buildViewTypeSelector(
    BuildContext context,
    CalendarProvider calendarProvider,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark
              ? AppColors.primaryDarkBlue.withOpacity(0.18)
              : AppColors.primaryBlue.withOpacity(0.18),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.08)
                : Colors.blue.withOpacity(0.06),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildViewTypeButton(
            context,
            'Week',
            CalendarViewType.week,
            calendarProvider,
          ),
          _buildViewTypeButton(
            context,
            'Month',
            CalendarViewType.month,
            calendarProvider,
          ),
        ],
      ),
    );
  }

  Widget _buildViewTypeButton(
    BuildContext context,
    String label,
    CalendarViewType viewType,
    CalendarProvider calendarProvider,
  ) {
    final isSelected = calendarProvider.viewType == viewType;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        calendarProvider.setViewType(viewType);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: isDark
                      ? [AppColors.primaryBlue, AppColors.accentTeal]
                      : [AppColors.primaryLightBlue, AppColors.accentLightTeal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected
              ? null
              : (isDark ? AppColors.surfaceDark : Colors.transparent),
          borderRadius: BorderRadius.circular(8.r),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.12)
                        : Colors.blue.withOpacity(0.10),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            color: isSelected
                ? Colors.white
                : (isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarView(
    BuildContext context,
    CalendarProvider calendarProvider,
  ) {
    switch (calendarProvider.viewType) {
      case CalendarViewType.week:
        return _buildWeekView(context, calendarProvider);
      case CalendarViewType.month:
        return _buildMonthView(context, calendarProvider);
      default:
        return _buildWeekView(context, calendarProvider);
    }
  }

  Widget _buildWeekView(
    BuildContext context,
    CalendarProvider calendarProvider,
  ) {
    final selectedDate = calendarProvider.selectedDate;
    final weekStart = selectedDate.subtract(
      Duration(days: selectedDate.weekday - 1),
    );

    return Container(
      height: 80.h,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: Column(
        children: [
          Row(
            children: List.generate(7, (index) {
              final date = weekStart.add(Duration(days: index));
              final isSelected =
                  date.day == selectedDate.day &&
                  date.month == selectedDate.month &&
                  date.year == selectedDate.year;
              final events = calendarProvider.getEventsForDate(date);

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    calendarProvider.setSelectedDate(date);
                    setState(() {
                      _focusedDate = date;
                    });
                  },
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 1.w),
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Column(
                      children: [
                        Text(
                          DateFormat('E').format(date),
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: isSelected
                                ? Colors.white
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        if (events.isNotEmpty)
                          Container(
                            width: 6.w,
                            height: 6.w,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthView(
    BuildContext context,
    CalendarProvider calendarProvider,
  ) {
    final selectedDate = calendarProvider.selectedDate;
    final firstDayOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
    final lastDayOfMonth = DateTime(
      selectedDate.year,
      selectedDate.month + 1,
      0,
    );
    final firstWeekday = firstDayOfMonth.weekday;
    final totalDays = lastDayOfMonth.day;

    // Calculate total weeks needed (including partial weeks)
    final totalWeeks = ((firstWeekday - 1) + totalDays + 6) ~/ 7;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: Column(
        children: [
          // Weekday headers
          Row(
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          SizedBox(height: 8.h),
          // Calendar grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: totalWeeks * 7, // Dynamic calculation
            itemBuilder: (context, index) {
              final dayOffset = index - firstWeekday + 1;
              final date = DateTime(
                selectedDate.year,
                selectedDate.month,
                dayOffset,
              );
              final isCurrentMonth = date.month == selectedDate.month;
              final isSelected =
                  date.day == selectedDate.day &&
                  date.month == selectedDate.month &&
                  date.year == selectedDate.year;
              final events = isCurrentMonth
                  ? calendarProvider.getEventsForDate(date)
                  : [];

              return GestureDetector(
                onTap: isCurrentMonth
                    ? () {
                        calendarProvider.setSelectedDate(date);
                        setState(() {
                          _focusedDate = date;
                        });
                      }
                    : null,
                child: Container(
                  margin: EdgeInsets.all(0.5.w),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: isCurrentMonth
                                ? (isSelected
                                      ? Colors.white
                                      : Theme.of(context).colorScheme.onSurface)
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.3),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        if (events.isNotEmpty && isCurrentMonth)
                          Container(
                            width: 4.w,
                            height: 4.w,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList(
    BuildContext context,
    CalendarProvider calendarProvider,
  ) {
    final events = calendarProvider.selectedDateEvents;

    if (events.isEmpty) {
      return Center(
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          margin: EdgeInsets.symmetric(horizontal: 32.w, vertical: 32.h),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 32.h, horizontal: 24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_busy,
                  size: 64.w,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.18),
                ),
                SizedBox(height: 20.h),
                Text(
                  'No events for ${DateFormat('MMMM d').format(calendarProvider.selectedDate)}',
                  style: TextStyle(
                    fontSize: 18.sp,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12.h),
                Text(
                  'Tap below to add a new event and stay organized!',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 18.h),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NewEventScreen(),
                      ),
                    );
                  },
                  icon: Icon(Icons.add),
                  label: Text('Add Event', style: TextStyle(fontSize: 15.sp)),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return Padding(
          padding: EdgeInsets.only(bottom: 8.h),
          child: EventCard(
            event: event,
            onTap: () => _showEventDetails(context, event),
          ),
        );
      },
    );
  }

  void _showEventDetails(BuildContext context, CalendarEvent event) {
    showDialog(
      context: context,
      builder: (context) => EventDetailsDialog(
        event: event,
        onEdit: () => _editEvent(event),
        onMarkCompleted: () => _markEventCompleted(event),
      ),
    );
  }

  void _editEvent(CalendarEvent event) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NewEventScreen(event: event)),
    );
  }

  void _markEventCompleted(CalendarEvent event) async {
    final calendarProvider = context.read<CalendarProvider>();
    calendarProvider.toggleEventCompletion(event.id);

    await NotificationService.sendEventNotification(
      title: 'Event Completed',
      body: 'Event "${event.title}" marked as completed.',
      payload: event.id,
    );
    // Optionally send voice call notification if enabled
    await NotificationService.sendVoiceCallNotification(
      callType: 'event',
      title: 'Event Completed',
      body: 'Congratulations! You completed the event ${event.title}.',
      payload: event.id,
    );
  }
}
