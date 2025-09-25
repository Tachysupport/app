import 'package:flutter/material.dart';
import '../models/calendar_event.dart';
import '../services/google_calendar_service.dart';
import '../services/firestore_calendar_service.dart';
import '../services/hive_storage_service.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../providers/app_provider.dart';
import '../main.dart';

class CalendarProvider extends ChangeNotifier {
  List<CalendarEvent> _events = [];
  DateTime _selectedDate = DateTime.now();
  CalendarViewType _viewType = CalendarViewType.week;
  bool _isLoading = false;
  bool _isGoogleCalendarEnabled = false;
  bool _isRefreshing = false;
  String? _lastSyncTime;
  String? _errorMessage;

  List<CalendarEvent> get events => _events;
  DateTime get selectedDate => _selectedDate;
  CalendarViewType get viewType => _viewType;
  bool get isLoading => _isLoading;
  bool get isGoogleCalendarEnabled => _isGoogleCalendarEnabled;
  bool get isRefreshing => _isRefreshing;
  String? get lastSyncTime => _lastSyncTime;
  String? get errorMessage => _errorMessage;

  List<CalendarEvent> get todayEvents {
    return _events.where((event) => event.isToday).toList();
  }

  List<CalendarEvent> get upcomingEvents {
    return _events.where((event) => event.isUpcoming).toList();
  }

  List<CalendarEvent> get overdueEvents {
    return _events.where((event) => event.isOverdue).toList();
  }

  List<CalendarEvent> get selectedDateEvents {
    return _events.where((event) {
      return event.startTime.year == _selectedDate.year &&
          event.startTime.month == _selectedDate.month &&
          event.startTime.day == _selectedDate.day;
    }).toList();
  }

  CalendarProvider() {
    _initializeProvider();
  }

  Future<void> _initializeProvider() async {
    await _loadSettings();
    await _loadEvents();
  }

  Future<void> _loadSettings() async {
    try {
      _isGoogleCalendarEnabled =
          await HiveStorageService.getSetting<bool>(
            'googleCalendarEnabled',
            defaultValue: false,
          ) ??
          false;
      _lastSyncTime = await HiveStorageService.getSetting<String>(
        'lastSyncTime',
      );
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> _loadEvents() async {
    _setLoading(true);
    _clearError();

    try {
      // Fetch both local and cloud events
      List<CalendarEvent> hiveEvents = await HiveStorageService.getEvents();
      List<CalendarEvent> cloudEvents = await FirestoreCalendarService.fetchEvents();

      // Build maps for fast lookup
      final Map<String, CalendarEvent> hiveMap = {for (var e in hiveEvents) e.id: e};
      final Map<String, CalendarEvent> cloudMap = {for (var e in cloudEvents) e.id: e};

      // Merge: upload local events not in cloud
      for (final id in hiveMap.keys) {
        if (!cloudMap.containsKey(id)) {
          await FirestoreCalendarService.addEvent(hiveMap[id]!);
        }
      }
      // Merge: download cloud events not in local
      for (final id in cloudMap.keys) {
        if (!hiveMap.containsKey(id)) {
          hiveMap[id] = cloudMap[id]!;
        }
      }

      // Use merged events
      _events = hiveMap.values.toList();
      await HiveStorageService.saveEvents(_events);
      debugPrint('Two-way sync complete: ${_events.length} events');

      // Validate events data
      _events = _events
          .where(
            (event) =>
                event.id.isNotEmpty &&
                event.title.isNotEmpty &&
                event.startTime.isBefore(event.endTime),
          )
          .toList();

      // Try to sync with Google Calendar, but don't block or fail app if it fails
      if (_isGoogleCalendarEnabled) {
        try {
          await _syncWithGoogleCalendar();
        } catch (e) {
          debugPrint('Google Calendar sync failed: $e');
        }
      }
    } catch (e) {
      debugPrint('Error loading events: $e');
      _setError('Failed to load events: ${e.toString()}');
      _events = [];
    } finally {
      _setLoading(false);
    }
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  void setViewType(CalendarViewType viewType) {
    _viewType = viewType;
    notifyListeners();
  }

  Future<void> addEvent(CalendarEvent event) async {
    // Add event to local and cloud
    _events.add(event);
    await HiveStorageService.saveEvents(_events);
    await FirestoreCalendarService.addEvent(event);
    notifyListeners();

    // Schedule notification for this event at its reminder time
    final context = navigatorKey.currentContext;
    if (context != null) {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final reminderMinutes = event.reminderMinutes;
      final reminderTime = event.startTime.subtract(Duration(minutes: reminderMinutes));
      final notificationId = event.id.hashCode;
      if (appProvider.settings['notificationsEnabled'] == true) {
        await NotificationService.plugin.zonedSchedule(
          notificationId,
          event.title,
          event.description,
          tz.TZDateTime.from(reminderTime, tz.local),
          NotificationDetails(
            android: AndroidNotificationDetails('event_reminder_channel', 'Event Reminders',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          androidAllowWhileIdle: true,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'event:${event.id}',
        );
      } else if (appProvider.settings['voiceCallEnabled'] == true) {
        await NotificationService.plugin.zonedSchedule(
          notificationId,
          '📞 Event Call: ${event.title}',
          'Tap to hear details about this event.',
          tz.TZDateTime.from(reminderTime, tz.local),
          NotificationDetails(
            android: AndroidNotificationDetails('event_call_channel', 'Event Calls',
              importance: Importance.max,
              priority: Priority.high,
              ongoing: false,
              sound: RawResourceAndroidNotificationSound('assistant_call'),
            ),
          ),
          androidAllowWhileIdle: true,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'eventcall:${event.id}',
        );
      }
    }

    // Try to add to Google Calendar if enabled, but don't block
    if (_isGoogleCalendarEnabled) {
      try {
        await GoogleCalendarService.createEvent(event);
        await _syncWithGoogleCalendar();
      } catch (e) {
        debugPrint('Google Calendar add failed: $e');
      }
    }
  }

  Future<void> updateEvent(CalendarEvent event) async {
    final index = _events.indexWhere((e) => e.id == event.id);
    if (index != -1) {
      // Update in local and cloud
      _events[index] = event;
      await HiveStorageService.saveEvents(_events);
      await FirestoreCalendarService.updateEvent(event);
      notifyListeners();

        // Cancel previous notification and reschedule
        final notificationId = event.id.hashCode;
        await NotificationService.plugin.cancel(notificationId);
        final context = navigatorKey.currentContext;
        if (context != null) {
          final appProvider = Provider.of<AppProvider>(context, listen: false);
          final reminderMinutes = event.reminderMinutes;
          final reminderTime = event.startTime.subtract(Duration(minutes: reminderMinutes));
          if (appProvider.settings['notificationsEnabled'] == true) {
            await NotificationService.plugin.zonedSchedule(
              notificationId,
              event.title,
              event.description,
              tz.TZDateTime.from(reminderTime, tz.local),
              NotificationDetails(
                android: AndroidNotificationDetails('event_reminder_channel', 'Event Reminders',
                  importance: Importance.max,
                  priority: Priority.high,
                ),
              ),
              androidAllowWhileIdle: true,
              uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
              payload: 'event:${event.id}',
            );
          } else if (appProvider.settings['voiceCallEnabled'] == true) {
            await NotificationService.plugin.zonedSchedule(
              notificationId,
              '📞 Event Call: ${event.title}',
              'Tap to hear details about this event.',
              tz.TZDateTime.from(reminderTime, tz.local),
              NotificationDetails(
                android: AndroidNotificationDetails('event_call_channel', 'Event Calls',
                  importance: Importance.max,
                  priority: Priority.high,
                  ongoing: false,
                  sound: RawResourceAndroidNotificationSound('assistant_call'),
                ),
              ),
              androidAllowWhileIdle: true,
              uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
              payload: 'eventcall:${event.id}',
            );
          }
        }

        // Try to update in Google Calendar if enabled
        if (_isGoogleCalendarEnabled && event.isGoogleCalendarEvent) {
          try {
            await GoogleCalendarService.updateEvent(event);
            await _syncWithGoogleCalendar();
          } catch (e) {
            debugPrint('Google Calendar update failed: $e');
          }
        }
    }
  }

  Future<void> deleteEvent(String eventId) async {
    CalendarEvent? event;
    try {
      event = _events.firstWhere((e) => e.id == eventId);
    } catch (_) {
      event = null;
    }
    if (event == null) return;

    // Cancel notification for this event
    final notificationId = event.id.hashCode;
    await NotificationService.plugin.cancel(notificationId);

    // Delete from local and cloud
    _events.removeWhere((e) => e.id == eventId);
    await HiveStorageService.saveEvents(_events);
    await FirestoreCalendarService.deleteEvent(eventId);
    notifyListeners();

    // Try to delete from Google Calendar if enabled
    if (_isGoogleCalendarEnabled && event.isGoogleCalendarEvent && event.googleEventId != null) {
      try {
        await GoogleCalendarService.deleteEvent(event.googleEventId!);
        await _syncWithGoogleCalendar();
      } catch (e) {
        debugPrint('Google Calendar delete failed: $e');
      }
    }
  }

  Future<void> toggleEventCompletion(String eventId) async {
    final index = _events.indexWhere((e) => e.id == eventId);
    if (index != -1) {
      final event = _events[index];
      final updatedEvent = event.copyWith(isCompleted: !event.isCompleted);
      _events[index] = updatedEvent;
      await HiveStorageService.saveEvents(_events);
      await FirestoreCalendarService.updateEvent(updatedEvent);
      notifyListeners();
    }
  }

  CalendarEvent? getNextEvent() {
    final now = DateTime.now();
    final upcoming = _events
        .where((event) => event.startTime.isAfter(now))
        .toList();

    if (upcoming.isEmpty) return null;

    upcoming.sort((a, b) => a.startTime.compareTo(b.startTime));
    return upcoming.first;
  }

  List<CalendarEvent> getEventsForDate(DateTime date) {
    return _events.where((event) {
      return event.startTime.year == date.year &&
          event.startTime.month == date.month &&
          event.startTime.day == date.day;
    }).toList();
  }

  List<CalendarEvent> getEventsForDateRange(DateTime start, DateTime end) {
    return _events.where((event) {
      return event.startTime.isAfter(start.subtract(const Duration(days: 1))) &&
          event.startTime.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  Future<void> refreshEvents() async {
    _setRefreshing(true);
    try {
      await _loadEvents();
    } finally {
      _setRefreshing(false);
    }
  }

  Future<void> enableGoogleCalendar() async {
    try {
      _setLoading(true);
      _clearError();

      final bool success = await GoogleCalendarService.signIn();
      if (success) {
        _isGoogleCalendarEnabled = true;
        await HiveStorageService.saveSetting('googleCalendarEnabled', true);
        await _syncWithGoogleCalendar();
        debugPrint('Google Calendar enabled successfully');
      } else {
        _setError('Failed to sign in to Google Calendar');
      }
    } catch (e) {
      debugPrint('Error enabling Google Calendar: $e');
      _setError('Failed to enable Google Calendar: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> disableGoogleCalendar() async {
    try {
      await GoogleCalendarService.signOut();
      _isGoogleCalendarEnabled = false;
      await HiveStorageService.saveSetting('googleCalendarEnabled', false);
      _lastSyncTime = null;
      await HiveStorageService.saveSetting('lastSyncTime', null);
      debugPrint('Google Calendar disabled');
      notifyListeners();
    } catch (e) {
      debugPrint('Error disabling Google Calendar: $e');
      _setError('Failed to disable Google Calendar: ${e.toString()}');
    }
  }

  Future<void> _syncWithGoogleCalendar() async {
    if (!_isGoogleCalendarEnabled) return;

    try {
      debugPrint('Syncing with Google Calendar...');

      // Fetch events from Google Calendar
      final List<CalendarEvent> googleEvents =
          await GoogleCalendarService.fetchEvents();

      // Merge with existing events (prioritize Google Calendar events)
      final Map<String, CalendarEvent> eventMap = {};

      // Add existing local events first
      for (final event in _events) {
        if (!event.isGoogleCalendarEvent) {
          eventMap[event.id] = event;
        }
      }

      // Add/update Google Calendar events
      for (final event in googleEvents) {
        eventMap[event.id] = event;
      }

      _events = eventMap.values.toList();
      await HiveStorageService.saveEvents(_events);

      _lastSyncTime = DateTime.now().toIso8601String();
      await HiveStorageService.saveSetting('lastSyncTime', _lastSyncTime);

      debugPrint('Synced ${googleEvents.length} events from Google Calendar');
      notifyListeners();
    } catch (e) {
      debugPrint('Error syncing with Google Calendar: $e');
      _setError('Failed to sync with Google Calendar: ${e.toString()}');
    }
  }

  Future<void> forceSyncWithGoogleCalendar() async {
    if (!_isGoogleCalendarEnabled) {
      _setError('Google Calendar is not enabled');
      return;
    }

    _setRefreshing(true);
    try {
      await _syncWithGoogleCalendar();
    } finally {
      _setRefreshing(false);
    }
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setRefreshing(bool refreshing) {
    _isRefreshing = refreshing;
    notifyListeners();
  }
}

enum CalendarViewType { day, week, month }
