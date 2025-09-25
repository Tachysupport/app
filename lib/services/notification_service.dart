import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/calendar_provider.dart';
import '../providers/auth_provider.dart';
import 'tts_service.dart';
import '../models/calendar_event.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class NotificationService {
  /// Call this once in app startup (main.dart) before scheduling notifications
  static void initializeTimezone() {
    tzdata.initializeTimeZones();
  }

  static final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  // Define notification channels
  static final AndroidNotificationChannel eventChannel =
      AndroidNotificationChannel(
        'event_channel',
        'Event Notifications',
        importance: Importance.high,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('notification_sound'),
        enableLights: true,
      );

  static final AndroidNotificationChannel callChannel =
      AndroidNotificationChannel(
        'call_channel',
        'Call Notifications',
        importance: Importance.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('assistant_call'),
        enableLights: true,
      );

  static final AndroidNotificationChannel reminderChannel =
      AndroidNotificationChannel(
        'reminder_channel',
        'Reminder Notifications',
        importance: Importance.high,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('notification_sound'),
        enableLights: true,
      );

  static Future<bool> requestPermissions() async {
    final platform = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (platform != null) {
      // Request precise alarms permission for scheduled notifications
      await platform.requestExactAlarmsPermission();
      // Request notification permission
      final granted = await platform.requestNotificationsPermission();
      return granted ?? false;
    }
    return false;
  }

  static Future<void> initialize() async {
    // Initialize timezone data
    tzdata.initializeTimeZones();

    // Request permissions first
    await requestPermissions();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    // Create notification channels
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(eventChannel);
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(callChannel);
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(reminderChannel);

    await plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (notificationResponse) async {
        final payload = notificationResponse.payload;
        if (payload != null && payload.startsWith('call:')) {
          // This is a call notification, show the overlay.
          await showCallNotification(
            callerName: payload.split(':')[1],
            callType: payload.split(':')[2],
          );
        }
      },
    );
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'default_channel',
          'General',
          importance: Importance.max,
          priority: Priority.high,
        );
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );
    await plugin.show(0, title, body, details, payload: payload);
  }

  /// Send event notification
  static Future<void> sendEventNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    // Use a unique ID for each notification to avoid overwriting
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        eventChannel.id,
        eventChannel.name,
        channelDescription: eventChannel.description,
        importance: eventChannel.importance,
        priority: Priority.high,
        sound: eventChannel.sound,
      ),
    );
    await plugin.show(id, title, body, details, payload: payload);
  }

  /// Send reminder notification
  static Future<void> sendReminderNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    // Use a unique ID for each notification to avoid overwriting
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        reminderChannel.id,
        reminderChannel.name,
        channelDescription: reminderChannel.description,
        importance: reminderChannel.importance,
        priority: Priority.high,
        sound: reminderChannel.sound,
      ),
    );
    await plugin.show(id, title, body, details, payload: payload);
  }

  /// Send voice call notification (TTS) for event
  static Future<void> sendVoiceCallNotification({
    required String callType,
    required String title,
    required String body,
    String? payload,
  }) async {
    // Use a unique ID for each notification to avoid overwriting
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        callChannel.id,
        callChannel.name,
        channelDescription: callChannel.description,
        importance: callChannel.importance,
        priority: Priority.max,
        sound: callChannel.sound,
        fullScreenIntent: true,
      ),
    );
    await plugin.show(id, title, body, details, payload: payload);
  }

  /// Schedule daily schedule call if enabled (background)
  static Future<void> scheduleDailyScheduleCall({
    required String ttsMessage,
    required String? callTime,
    required bool isEnabled,
  }) async {
    if (isEnabled && callTime != null) {
      final parts = callTime.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      // Schedule notification using flutter_local_notifications
      const AndroidNotificationDetails
      androidDetails = AndroidNotificationDetails(
        'daily_schedule_call_channel',
        'Daily Schedule Call',
        importance: Importance.max,
        priority: Priority.high,
        ongoing: false,
        sound: RawResourceAndroidNotificationSound(
          'assistant_call',
        ), // Custom sound (add assistant_call.mp3 to android/app/src/main/res/raw)
      );
      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
      );
      await plugin.zonedSchedule(
        1001, // Unique ID for daily schedule call
        '📞 Daily Schedule Call',
        'Tap to pick your daily schedule briefing call.',
        _nextInstanceOfTime(hour, minute),
        details,
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'call:Assistant:schedule',
      );
    }
  }

  /// Helper to get next instance of a time (today or tomorrow)
  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Creative workaround for call-style notification with Accept/Decline
  static Future<void> showCallNotification({
    String? callerName,
    String? callType,
    String? audioBrief,
  }) async {
    // Ensure we have permission to show overlays
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (!granted) {
      // This will prompt the user to grant permission
      await FlutterOverlayWindow.requestPermission();
      return; // Return early, user needs to grant permission first
    }

    if (await FlutterOverlayWindow.isActive())
      return; // Avoid showing multiple overlays

    await FlutterOverlayWindow.showOverlay(
      height: 800, // Adjust size as needed
      width: 500,
      alignment: OverlayAlignment.center,
      flag: OverlayFlag.focusPointer,
      enableDrag: true,
    );
    // Send data to the overlay
    await FlutterOverlayWindow.shareData({
      'callerName': callerName ?? 'Assistant',
      'callType': callType ?? 'schedule',
      'audioBrief': audioBrief ?? '',
    });
  }

  /// Handle Accept/Decline logic in app-side code
  static void handleNotificationAction(String? payload, BuildContext context) {
    if (payload == null) return;
    if (payload.startsWith('call:')) {
      final calendarProvider = Provider.of<CalendarProvider>(
        context,
        listen: false,
      );
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final todayEvents = calendarProvider.todayEvents;
      Future(() async {
        String userName = await authProvider.getUserDisplayName();
        final briefing = TtsService.generateAdvancedScheduleBriefing(
          userName: userName,
          events: todayEvents,
          now: DateTime.now(),
        );
        await FlutterOverlayWindow.showOverlay();
        await FlutterOverlayWindow.shareData({
          'callerName': 'Assistant',
          'callType': 'schedule',
          'audioBrief': briefing,
        });
      });
    } else if (payload.startsWith('eventcall:')) {
      final eventId = payload.replaceFirst('eventcall:', '');
      final calendarProvider = Provider.of<CalendarProvider>(
        context,
        listen: false,
      );
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      CalendarEvent? event;
      try {
        event = calendarProvider.events.firstWhere((e) => e.id == eventId);
      } catch (_) {
        event = null;
      }
      if (event != null) {
        Future(() async {
          String userName = await authProvider.getUserDisplayName();
          final briefing = TtsService.generateEventBriefing(
            userName: userName,
            event: event!,
          );
          await FlutterOverlayWindow.showOverlay();
          await FlutterOverlayWindow.shareData({
            'callerName': userName,
            'callType': 'event',
            'audioBrief': briefing,
          });
        });
      }
    }
  }
}
