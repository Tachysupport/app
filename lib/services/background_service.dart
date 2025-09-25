import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../services/notification_service.dart';
import '../services/hive_storage_service.dart';

// THIS IS THE FIX: Move onStart and its helpers outside the class.
@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  bool isAppInForeground = true;

  service.on('setAsForeground').listen((event) {
    isAppInForeground = true;
  });
  service.on('setAsBackground').listen((event) {
    isAppInForeground = false;
  });

  // Run every 1 minute
  Timer.periodic(const Duration(minutes: 1), (timer) async {
    // Ensure we are running on Android.
    if (service is! AndroidServiceInstance) {
      // If not on android, stop the timer.
      timer.cancel();
      return;
    }

    // Ensure the service is running as a foreground service
    if (!await service.isForegroundService()) {
      await service.setAsForegroundService();
    }

    // Load settings and events from Hive
    await HiveStorageService.initialize();
    final settings = await HiveStorageService.getAllSettings();
    final events = await HiveStorageService.getEvents();
    final now = DateTime.now();

    // --- Process Event-Based Notifications ---
    for (final event in events) {
      // Skip completed events
      if (event.isCompleted) continue;

      final hasReminder = event.reminderMinutes > 0;
      final reminderTime = hasReminder
          ? event.startTime.subtract(Duration(minutes: event.reminderMinutes))
          : event.startTime;

      // 1. Voice Call Reminders (Highest Priority)
      if (settings['voiceCallEnabled'] == true && hasReminder) {
        if (_isWithinWindow(reminderTime, now, 60)) {
          await NotificationService.sendVoiceCallNotification(
            callType: 'event',
            title: 'Event Call',
            body: 'Reminder: ${event.title} starts soon.',
            payload: event.id,
          );
          // Skip other notifications for this event if a call is made
          continue;
        }
      }

      // 2. Standard Event Notifications (if voice calls are off)
      if (settings['notificationsEnabled'] == true) {
        // Reminder Notification
        if (hasReminder && _isWithinWindow(reminderTime, now, 60)) {
          await NotificationService.sendReminderNotification(
            title: 'Event Reminder',
            body: '${event.title} starts at ${_formatTime(event.startTime)}',
            payload: event.id,
          );
        }
        // Event Start Notification
        if (_isWithinWindow(event.startTime, now, 60)) {
          await NotificationService.sendEventNotification(
            title: 'Event Started',
            body: '${event.title} is starting now.',
            payload: event.id,
          );
        }
      }
    }

    // --- Process Daily Schedule Call ---
    if (settings['dailyScheduleCallEnabled'] == true &&
        settings['dailyScheduleCallTime'] != null) {
      final scheduleTime = _parseTodayTime(settings['dailyScheduleCallTime']);
      if (_isWithinWindow(scheduleTime, now, 60)) {
        if (isAppInForeground) {
          // FOREGROUND: Show the overlay directly
          await NotificationService.showCallNotification(
            callerName: 'Assistant',
            callType: 'schedule',
          );
        } else {
          // BACKGROUND: Send a standard push notification
          await NotificationService.scheduleDailyScheduleCall(
            ttsMessage: "Here is your daily schedule briefing.",
            callTime: settings['dailyScheduleCallTime'],
            isEnabled: settings['dailyScheduleCallEnabled'],
          );
        }
      }
    }
  });
}

/// Returns true if [target] is within the same minute as [now]
bool _isWithinWindow(DateTime target, DateTime now, int windowSeconds) {
  // This is a more robust way to check if the notification should fire.
  // It checks if the target time is in the past but within the last minute.
  final diff = now.difference(target).inSeconds;
  return diff >= 0 && diff < windowSeconds;
}

String _formatTime(DateTime dt) {
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $ampm';
}

DateTime _parseTodayTime(String timeStr) {
  final parts = timeStr.split(':');
  final now = DateTime.now();
  return DateTime(
    now.year,
    now.month,
    now.day,
    int.parse(parts[0]),
    int.parse(parts[1]),
  );
}

class BackgroundService {
  static Future<void> initialize() async {
    await FlutterBackgroundService().configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart, // Now correctly points to the top-level function
        autoStart: true,
        isForegroundMode: true,
        initialNotificationTitle: 'My Assistant Running',
        initialNotificationContent: 'Background notifications enabled',
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false, // Not needed for Android-only
      ),
    );
  }
}
