import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../providers/app_provider.dart';
import '../providers/calendar_provider.dart';
import '../providers/auth_provider.dart';
import '../models/calendar_event.dart';
import '../widgets/event_card.dart';
import '../widgets/event_details_dialog.dart';
import '../services/tts_service.dart';
import 'package:flutter/scheduler.dart';
import './new_event.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isPlayingVoice = false;
  int _selectedTab = 0; // 0: Today's Events, 1: Upcoming Events

  late DateTime _now;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _ticker = Ticker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final now = DateTime.now();
    if (_now.minute != now.minute) {
      setState(() {
        _now = now;
      });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Main widget tree for HomeScreen
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Consumer2<AppProvider, CalendarProvider>(
          builder: (context, appProvider, calendarProvider, child) {
            return LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    // The IntrinsicHeight widget was causing the overflow and has been removed.
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildAppBar(context, appProvider),
                        _buildGreeting(context),
                        _buildScheduleBriefing(context, calendarProvider),
                        _buildEventTabs(context, calendarProvider),
                        // This SizedBox provides the bottom margin you wanted.
                        SizedBox(height: 80.h),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, AppProvider appProvider) {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0, // Use Material 3 elevation system
      centerTitle: false,
      title: Padding(
        padding: EdgeInsets.only(left: 8.w),
        child: Text(
          'My Personal Assistant',
          style: TextStyle(
            fontSize: 22.sp,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Consumer<CalendarProvider>(
            builder: (context, calendarProvider, child) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  calendarProvider.isGoogleCalendarEnabled
                      ? Icons.sync
                      : Icons.sync_problem,
                  color: calendarProvider.isGoogleCalendarEnabled
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                  key: ValueKey(calendarProvider.isGoogleCalendarEnabled),
                ),
              );
            },
          ),
          onPressed: () {
            final calendarProvider = context.read<CalendarProvider>();
            if (calendarProvider.isGoogleCalendarEnabled) {
              calendarProvider.forceSyncWithGoogleCalendar();
            } else {
              _showGoogleCalendarDialog(context, calendarProvider);
            }
          },
          tooltip: context.watch<CalendarProvider>().isGoogleCalendarEnabled
              ? 'Sync with Google Calendar'
              : 'Enable Google Calendar',
        ),
        IconButton(
          icon: Icon(
            Icons.refresh,
            color: Theme.of(context).colorScheme.primary,
          ),
          onPressed: () {
            context.read<CalendarProvider>().refreshEvents();
          },
          tooltip: 'Refresh events',
        ),
        SizedBox(width: 8.w),
      ],
    );
  }

  Widget _buildGreeting(BuildContext context) {
    final now = _now;
    final hour = now.hour;
    String greeting;
    IconData greetingIcon;
    Color greetingColor;

    if (hour >= 0 && hour < 5) {
      // Late night/Early morning (12 AM - 5 AM)
      greeting = 'Good Night';
      greetingIcon = Icons.nights_stay;
      greetingColor = Colors.indigo;
    } else if (hour >= 5 && hour < 12) {
      // Morning (5 AM - 12 PM)
      greeting = 'Good Morning';
      greetingIcon = Icons.wb_sunny;
      greetingColor = Colors.orange;
    } else if (hour >= 12 && hour < 17) {
      // Afternoon (12 PM - 5 PM)
      greeting = 'Good Afternoon';
      greetingIcon = Icons.wb_sunny_outlined;
      greetingColor = Colors.amber;
    } else if (hour >= 17 && hour < 21) {
      // Evening (5 PM - 9 PM)
      greeting = 'Good Evening';
      greetingIcon = Icons.wb_twilight;
      greetingColor = Colors.deepOrange;
    } else {
      // Night (9 PM - 12 AM)
      greeting = 'Good Night';
      greetingIcon = Icons.nights_stay;
      greetingColor = Colors.indigo;
    }

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return FutureBuilder<String>(
          future: authProvider.getUserDisplayName(),
          builder: (context, snapshot) {
            String userName = snapshot.data ?? 'there';

            return Container(
              width: double.infinity,
              margin: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 20.h),
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: greetingColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: greetingColor.withOpacity(0.3),
                  width: 1.w,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: greetingColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Icon(
                          greetingIcon,
                          color: greetingColor,
                          size: 28.w,
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName.toLowerCase() == 'there'
                                  ? '$greeting!'
                                  : '$greeting, $userName!',
                              style: TextStyle(
                                fontSize: 24.sp,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    DateFormat('EEEE, MMMM d').format(now),
                                    style: TextStyle(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 4.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: greetingColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 12.w,
                                        color: greetingColor,
                                      ),
                                      SizedBox(width: 4.w),
                                      Text(
                                        DateFormat('h:mm a').format(now),
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w600,
                                          color: greetingColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getPersonalizedMessage(hour),
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.8),
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            _buildStatusIndicator(
                              context,
                              Icons.mood,
                              _getMoodText(hour),
                              Colors.green,
                            ),
                            SizedBox(width: 12.w),
                            _buildStatusIndicator(
                              context,
                              Icons.energy_savings_leaf,
                              _getEnergyText(hour),
                              Colors.teal,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusIndicator(
    BuildContext context,
    IconData icon,
    String text,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withOpacity(0.2), width: 1.w),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.w, color: color),
          SizedBox(width: 4.w),
          Text(
            text,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getPersonalizedMessage(int hour) {
    if (hour >= 0 && hour < 5) {
      // Late night/Very early morning (12 AM - 5 AM)
      return "It's quite late! Consider getting some rest to recharge for tomorrow.";
    } else if (hour >= 5 && hour < 7) {
      // Early morning (5 AM - 7 AM)
      return "Rise and shine! Early morning is perfect for meditation and planning your day.";
    } else if (hour >= 7 && hour < 9) {
      // Morning start (7 AM - 9 AM)
      return "Perfect time to start the day! Your morning energy is at its peak.";
    } else if (hour >= 9 && hour < 12) {
      // Mid morning (9 AM - 12 PM)
      return "Great time for focused work and tackling your most important tasks.";
    } else if (hour >= 12 && hour < 14) {
      // Early afternoon (12 PM - 2 PM)
      return "Lunch time! Fuel up and take a break to maintain your energy levels.";
    } else if (hour >= 14 && hour < 17) {
      // Mid afternoon (2 PM - 5 PM)
      return "Afternoon productivity time! Perfect for collaborative work and meetings.";
    } else if (hour >= 17 && hour < 19) {
      // Early evening (5 PM - 7 PM)
      return "Evening time to wrap up work and transition to personal time.";
    } else if (hour >= 19 && hour < 21) {
      // Evening (7 PM - 9 PM)
      return "Perfect time for dinner, family, and enjoying your personal interests.";
    } else {
      // Night (9 PM - 12 AM)
      return "Winding down time. Perfect for reflection, relaxation, and preparing for rest.";
    }
  }

  String _getMoodText(int hour) {
    if (hour < 6) return "Sleepy";
    if (hour < 12) return "Fresh";
    if (hour < 17) return "Active";
    return "Calm";
  }

  String _getEnergyText(int hour) {
    if (hour < 6) return "Low";
    if (hour < 10) return "High";
    if (hour < 15) return "Peak";
    if (hour < 18) return "Good";
    return "Moderate";
  }

  String _formatLastSyncTime(String syncTime) {
    try {
      final DateTime sync = DateTime.parse(syncTime);
      final DateTime now = DateTime.now();
      final Duration difference = now.difference(sync);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  Widget _buildScheduleBriefing(
    BuildContext context,
    CalendarProvider calendarProvider,
  ) {
    final todayEvents = calendarProvider.todayEvents;
    final nextEvent = calendarProvider.getNextEvent();

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(
                  Icons.schedule,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 26.w,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Schedule',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Your daily overview',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _isPlayingVoice
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28.w,
                ),
                onPressed: () {
                  _playScheduleBriefing(todayEvents, nextEvent);
                },
                tooltip: _isPlayingVoice ? 'Stop briefing' : 'Play briefing',
              ),
            ],
          ),
          SizedBox(height: 16.h),
          if (calendarProvider.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (todayEvents.isEmpty)
            Text(
              'No events scheduled for today. Enjoy your free time!',
              style: TextStyle(
                fontSize: 14.sp,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You have ${todayEvents.length} event${todayEvents.length == 1 ? '' : 's'} today.',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (nextEvent != null) ...[
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.arrow_forward,
                          size: 16.w,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Next: ${nextEvent.title} at ${nextEvent.timeRange}',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (calendarProvider.isGoogleCalendarEnabled) ...[
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Icon(
                        Icons.cloud_done_outlined,
                        size: 14.w,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'Synced with Google',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (calendarProvider.lastSyncTime != null) ...[
                        SizedBox(width: 4.w),
                        Text(
                          '• ${_formatLastSyncTime(calendarProvider.lastSyncTime!)}',
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEventTabs(
    BuildContext context,
    CalendarProvider calendarProvider,
  ) {
    final todayEvents = calendarProvider.todayEvents;
    final upcomingEvents = calendarProvider.upcomingEvents;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTabButton('Today\'s Events', 0),
                _buildTabButton('Upcoming Events', 1),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          AnimatedSwitcher(
            duration: Duration(milliseconds: 300),
            child: _selectedTab == 0
                ? _buildEventsList(context, todayEvents, isCompact: false)
                : _buildEventsList(context, upcomingEvents, isCompact: true),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            if (!isSelected)
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
          ],
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : Theme.of(context).colorScheme.primary.withOpacity(0.1),
            width: 1.5.w,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              index == 0 ? Icons.today : Icons.event_note,
              size: 18.w,
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).colorScheme.primary.withOpacity(0.8),
            ),
            SizedBox(width: 8.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsList(
    BuildContext context,
    List<CalendarEvent> events, {
    bool isCompact = false,
  }) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_note,
              size: 64.w,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
            ),
            SizedBox(height: 16.h),
            Text(
              _selectedTab == 0
                  ? 'No events today! You\'re all caught up.'
                  : 'No upcoming events! You\'re all caught up.',
              style: TextStyle(
                fontSize: 16.sp,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              '💡 Tap below to add a new event',
              style: TextStyle(
                fontSize: 12.sp,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            ElevatedButton.icon(
              icon: Icon(Icons.add),
              label: Text('Add Event'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/new_event');
              },
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Add a subtle header for the event list
        if (!isCompact && events.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Text(
              _selectedTab == 0 ? 'Today\'s Events' : 'Upcoming Events',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ),
        ],
        ...events.map(
          (event) => Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: EventCard(
              event: event,
              isCompact: isCompact,
              onTap: () => _onEventTap(event),
            ),
          ),
        ),
      ],
    );
  }

  void _onEventTap(CalendarEvent event) {
    showDialog(
      context: context,
      builder: (context) => EventDetailsDialog(
        event: event,
        onEdit: () => _editEvent(event),
        onMarkCompleted: () => _markEventCompleted(event),
      ),
    );
  }

  void _markEventCompleted(CalendarEvent event) {
    final calendarProvider = context.read<CalendarProvider>();
    calendarProvider.toggleEventCompletion(event.id);
  }

  void _editEvent(CalendarEvent event) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NewEventScreen(event: event)),
    );
  }

  void _playScheduleBriefing(
    List<CalendarEvent> events,
    CalendarEvent? nextEvent,
  ) async {
    if (_isPlayingVoice) {
      await TtsService.stop();
      setState(() {
        _isPlayingVoice = false;
      });
    } else {
      setState(() {
        _isPlayingVoice = true;
      });
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      String userName = await authProvider.getUserDisplayName();
      String briefingText = _generateScheduleBriefing(
        events,
        nextEvent,
        userName,
      );
      await TtsService.speak(briefingText);
      // Wait for TTS to finish before resetting icon
      // fallback: delay for a reasonable time (since TtsService.awaitCompletion is not defined)
      await Future.delayed(const Duration(seconds: 5));
      if (mounted) {
        setState(() {
          _isPlayingVoice = false;
        });
      }
    }
  }

  String _generateScheduleBriefing(
    List<CalendarEvent> events,
    CalendarEvent? nextEvent,
    String userName,
  ) {
    final now = DateTime.now();
    String greeting;
    if (now.hour < 12) {
      greeting = 'Good morning';
    } else if (now.hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }
    StringBuffer briefing = StringBuffer();
    briefing.write(
      "$greeting, $userName! You have ${events.length} event${events.length == 1 ? '' : 's'} scheduled for today. ",
    );
    if (events.isEmpty) {
      return "$greeting, $userName! You have no events scheduled for today. Enjoy your free time! Would you like to add a new event?";
    }

    for (int i = 0; i < events.length; i++) {
      final event = events[i];
      final start = event.timeRange.split(' - ').first;
      final end = event.timeRange.split(' - ').last;
      briefing.write(
        "\nAt $start today, you have an event titled '${event.title}'.",
      );
      if (event.description.isNotEmpty) {
        briefing.write(" Description: ${event.description}.");
      }
      if (event.location.isNotEmpty) {
        briefing.write(" Location: ${event.location}.");
      }
      briefing.write(" Starts at $start, ends at $end.");
      if (i < events.length - 1) {
        final nextEvent = events[i + 1];
        final nextStart = nextEvent.timeRange.split(' - ').first;
        briefing.write(" Next event is at $nextStart.");
      }
    }

    briefing.write("\nWishing you a productive and organized day!");
    return briefing.toString();
  }

  void _showGoogleCalendarDialog(
    BuildContext context,
    CalendarProvider calendarProvider,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Enable Google Calendar',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Connect your Google Calendar to sync events across all your devices.',
                style: TextStyle(fontSize: 14.sp),
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20.w,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Real-time sync',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  Icon(
                    Icons.cloud_sync,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20.w,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Automatic updates',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  Icon(
                    Icons.security,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20.w,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Secure authentication',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(fontSize: 14.sp)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await calendarProvider.enableGoogleCalendar();
              },
              child: Text('Connect', style: TextStyle(fontSize: 14.sp)),
            ),
          ],
        );
      },
    );
  }
}
