import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/app_provider.dart';
import 'providers/calendar_provider.dart';
import 'providers/auth_provider.dart';
import 'services/hive_storage_service.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';
import 'widgets/auth_wrapper.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'screens/new_event.dart';

// Global navigator key for accessing context outside widgets
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  // Ensure Flutter is ready
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone data (required for notifications)
  tzdata.initializeTimeZones();
  // Set local location to ensure correct notification timing
  tz.setLocalLocation(tz.getLocation('UTC'));

  // --- CRITICAL INITIALIZATION STEPS ---
  await HiveStorageService.initialize();
  await NotificationService.initialize(); // <-- Initializes with tap handler now
  await BackgroundService.initialize();
  await requestOverlayPermission();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());

  // After app starts, trigger calendar refresh from Google Calendar
  // Wait for the first frame to ensure providers are available
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      final calendarProvider = Provider.of<CalendarProvider>(
        context,
        listen: false,
      );
      calendarProvider.refreshEvents();
      rescheduleAllEventNotifications(context);
    }
  });

  // Periodically reschedule notifications on app resume
  WidgetsBinding.instance.addObserver(_AppLifecycleObserver());
}

// Helper to reschedule all event notifications (call after refresh, settings change, etc)
void rescheduleAllEventNotifications(BuildContext context) async {
  final calendarProvider = Provider.of<CalendarProvider>(
    context,
    listen: false,
  );
  final appProvider = Provider.of<AppProvider>(context, listen: false);
  for (final event in calendarProvider.events) {
    final reminderMinutes = event.reminderMinutes;
    final reminderTime = event.startTime.subtract(
      Duration(minutes: reminderMinutes),
    );
    final notificationId = event.id.hashCode;
    // If voice calls are on, schedule a call notification.
    if (appProvider.settings['voiceCallEnabled'] == true) {
      await NotificationService.plugin.zonedSchedule(
        notificationId,
        '📞 Event Call: ${event.title}',
        'Tap to hear details about this event.',
        tz.TZDateTime.from(reminderTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'event_call_channel',
            'Event Calls',
            importance: Importance.max,
            priority: Priority.high,
            ongoing: false,
            sound: RawResourceAndroidNotificationSound('assistant_call'),
          ),
        ),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'eventcall:${event.id}',
      );
    }
    // Otherwise, if general notifications are on, schedule a standard one.
    else if (appProvider.settings['notificationsEnabled'] == true) {
      await NotificationService.plugin.zonedSchedule(
        notificationId,
        event.title,
        event.description,
        tz.TZDateTime.from(reminderTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'event_reminder_channel',
            'Event Reminders',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'event:${event.id}',
      );
    }
  }
}

// Observer to reschedule notifications on app resume
class _AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        rescheduleAllEventNotifications(context);
      }
    }
  }
}

// Call this before showing overlays
Future<void> requestOverlayPermission() async {
  final granted = await FlutterOverlayWindow.isPermissionGranted();
  if (!granted) {
    await FlutterOverlayWindow.requestPermission();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, CalendarProvider>(
          create: (_) => CalendarProvider(),
          update: (_, auth, prev) => prev ?? CalendarProvider(),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          final appProvider = Provider.of<AppProvider>(context);
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'My Personal Assistant',
            theme: appProvider.theme,
            home: const AuthWrapper(),
            routes: {
              '/new_event': (context) => const NewEventScreen(),
              '/edit_event': (context) => const NewEventScreen(),
            },
          );
        },
      ),
    );
  }
}
