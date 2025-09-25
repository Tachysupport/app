import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/calendar_event.dart';

class _GoogleAuthClient extends http.BaseClient {
  final GoogleSignInAccount _account;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._account);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers.addAll(await _account.authHeaders);
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}

class GoogleCalendarService {
  static const List<String> _scopes = [
    calendar.CalendarApi.calendarScope,
    calendar.CalendarApi.calendarReadonlyScope,
  ];

  static GoogleSignIn? _googleSignIn;
  static calendar.CalendarApi? _calendarApi;
  static http.Client? _authClient;

  static Future<void> initialize() async {
    _googleSignIn = GoogleSignIn(scopes: _scopes);
  }

  static Future<bool> isSignedIn() async {
    if (_googleSignIn == null) await initialize();
    return await _googleSignIn!.isSignedIn();
  }

  static Future<bool> signIn() async {
    try {
      if (_googleSignIn == null) await initialize();

      final GoogleSignInAccount? account = await _googleSignIn!.signIn();
      if (account == null) return false;

      _authClient = _GoogleAuthClient(account);
      _calendarApi = calendar.CalendarApi(_authClient!);

      return true;
    } catch (e) {
      debugPrint('Google Calendar sign in error: $e');
      return false;
    }
  }

  static Future<void> signOut() async {
    if (_googleSignIn != null) {
      await _googleSignIn!.signOut();
    }
    _authClient?.close();
    _authClient = null;
    _calendarApi = null;
  }

  static Future<List<CalendarEvent>> fetchEvents({
    DateTime? startTime,
    DateTime? endTime,
    int maxResults = 100,
  }) async {
    if (_calendarApi == null) {
      throw Exception('Not signed in to Google Calendar');
    }

    try {
      final DateTime now = DateTime.now();
      final DateTime start =
          startTime ?? now.subtract(const Duration(days: 30));
      final DateTime end = endTime ?? now.add(const Duration(days: 30));

      final calendar.Events events = await _calendarApi!.events.list(
        'primary',
        timeMin: start.toUtc(),
        timeMax: end.toUtc(),
        maxResults: maxResults,
        singleEvents: true,
        orderBy: 'startTime',
      );

      final List<CalendarEvent> calendarEvents = [];

      for (final calendar.Event event in events.items ?? []) {
        try {
          final CalendarEvent calendarEvent =
              _convertGoogleEventToCalendarEvent(event);
          calendarEvents.add(calendarEvent);
        } catch (e) {
          debugPrint('Error converting event ${event.id}: $e');
          continue;
        }
      }

      return calendarEvents;
    } catch (e) {
      debugPrint('Error fetching Google Calendar events: $e');
      rethrow;
    }
  }

  static Future<List<CalendarEvent>> fetchTodayEvents() async {
    final DateTime now = DateTime.now();
    final DateTime startOfDay = DateTime(now.year, now.month, now.day);
    final DateTime endOfDay = DateTime(
      now.year,
      now.month,
      now.day,
      23,
      59,
      59,
    );

    return await fetchEvents(startTime: startOfDay, endTime: endOfDay);
  }

  static Future<List<CalendarEvent>> fetchUpcomingEvents() async {
    final DateTime now = DateTime.now();
    final DateTime endOfWeek = now.add(const Duration(days: 7));

    return await fetchEvents(startTime: now, endTime: endOfWeek);
  }

  static CalendarEvent _convertGoogleEventToCalendarEvent(
    calendar.Event event,
  ) {
    final DateTime startTime = _parseDateTime(event.start);
    final DateTime endTime = _parseDateTime(event.end);

    // Determine event color based on Google Calendar color
    Color eventColor = _getColorFromGoogleColorId(event.colorId);

    return CalendarEvent(
      id: event.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: event.summary ?? 'Untitled Event',
      description: event.description ?? '',
      startTime: startTime,
      endTime: endTime,
      location: event.location ?? '',
      color: eventColor,
      isGoogleCalendarEvent: true,
      googleEventId: event.id,
      isCompleted: false,
      notes: event.description,
      reminderMinutes: _getReminderMinutes(event.reminders),
      recurrence: _getRecurrenceRule(event.recurrence),
      attachment: _getAttachments(event.attachments),
      isAllDay: event.start?.date != null,
    );
  }

  static DateTime _parseDateTime(calendar.EventDateTime? dateTime) {
    if (dateTime?.dateTime != null) {
      return dateTime!.dateTime!;
    } else if (dateTime?.date != null) {
      // date is a DateTime, not a String, so just return it
      if (dateTime!.date is DateTime) {
        return dateTime.date as DateTime;
      } else if (dateTime.date is String) {
        return DateTime.parse(dateTime.date as String);
      } else {
        return DateTime.now();
      }
    } else {
      return DateTime.now();
    }
  }

  static Color _getColorFromGoogleColorId(String? colorId) {
    final Map<String, Color> colorMap = {
      '1': Colors.blue, // Lavender
      '2': Colors.green, // Sage
      '3': Colors.purple, // Grape
      '4': Colors.pink, // Flamingo
      '5': Colors.yellow, // Banana
      '6': Colors.orange, // Tangerine
      '7': Colors.teal, // Peacock
      '8': Colors.grey, // Graphite
      '9': Colors.indigo, // Blueberry
      '10': Colors.lightGreen, // Basil
      '11': Colors.red, // Tomato
    };

    return colorMap[colorId] ?? Colors.blue;
  }

  static int _getReminderMinutes(calendar.EventReminders? reminders) {
    if (reminders?.overrides == null || reminders!.overrides!.isEmpty) {
      return 15; // Default reminder
    }

    final calendar.EventReminder reminder = reminders.overrides!.first;
    if (reminder.minutes != null) {
      return reminder.minutes!;
    }

    return 15;
  }

  static String _getRecurrenceRule(List<String>? recurrence) {
    if (recurrence == null || recurrence.isEmpty) {
      return 'Does not repeat';
    }

    // Parse RRULE to get human-readable recurrence
    final String rrule = recurrence.first;
    if (rrule.contains('FREQ=DAILY')) {
      return 'Daily';
    } else if (rrule.contains('FREQ=WEEKLY')) {
      return 'Weekly';
    } else if (rrule.contains('FREQ=MONTHLY')) {
      return 'Monthly';
    } else if (rrule.contains('FREQ=YEARLY')) {
      return 'Yearly';
    }

    return 'Custom';
  }

  static String _getAttachments(List<calendar.EventAttachment>? attachments) {
    if (attachments == null || attachments.isEmpty) {
      return '';
    }

    return attachments.map((att) => att.fileUrl ?? '').join(', ');
  }

  static Future<bool> createEvent(CalendarEvent event) async {
    if (_calendarApi == null) {
      throw Exception('Not signed in to Google Calendar');
    }

    try {
      final calendar.Event googleEvent = calendar.Event(
        summary: event.title,
        description: event.description,
        location: event.location,
        start: calendar.EventDateTime(
          dateTime: event.startTime.toUtc(),
          timeZone: 'UTC',
        ),
        end: calendar.EventDateTime(
          dateTime: event.endTime.toUtc(),
          timeZone: 'UTC',
        ),
        reminders: calendar.EventReminders(
          useDefault: false,
          overrides: [
            calendar.EventReminder(
              method: 'popup',
              minutes: event.reminderMinutes,
            ),
          ],
        ),
      );

      await _calendarApi!.events.insert(googleEvent, 'primary');
      return true;
    } catch (e) {
      debugPrint('Error creating Google Calendar event: $e');
      return false;
    }
  }

  static Future<bool> updateEvent(CalendarEvent event) async {
    if (_calendarApi == null || event.googleEventId == null) {
      throw Exception(
        'Not signed in to Google Calendar or event not from Google',
      );
    }

    try {
      final calendar.Event googleEvent = calendar.Event(
        summary: event.title,
        description: event.description,
        location: event.location,
        start: calendar.EventDateTime(
          dateTime: event.startTime.toUtc(),
          timeZone: 'UTC',
        ),
        end: calendar.EventDateTime(
          dateTime: event.endTime.toUtc(),
          timeZone: 'UTC',
        ),
        reminders: calendar.EventReminders(
          useDefault: false,
          overrides: [
            calendar.EventReminder(
              method: 'popup',
              minutes: event.reminderMinutes,
            ),
          ],
        ),
      );

      await _calendarApi!.events.update(
        googleEvent,
        'primary',
        event.googleEventId!,
      );
      return true;
    } catch (e) {
      debugPrint('Error updating Google Calendar event: $e');
      return false;
    }
  }

  static Future<bool> deleteEvent(String googleEventId) async {
    if (_calendarApi == null) {
      throw Exception('Not signed in to Google Calendar');
    }

    try {
      await _calendarApi!.events.delete('primary', googleEventId);
      return true;
    } catch (e) {
      debugPrint('Error deleting Google Calendar event: $e');
      return false;
    }
  }
}