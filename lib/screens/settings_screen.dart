import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/calendar_provider.dart';
import '../services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // No need to initialize notifications here as it's done in main.dart
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600),
        ),
      ),
      body: Consumer<AppProvider>(
        builder: (context, appProvider, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProfileSection(context, appProvider),
                    SizedBox(height: 18.h),
                    _buildNotificationSettings(context, appProvider),
                    _buildVoiceSettings(context, appProvider),
                    _buildCalendarSettings(context, appProvider),
                    _buildPrivacySettings(context, appProvider),
                    _buildUISettings(context, appProvider),
                    _buildAboutSection(context),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context, AppProvider appProvider) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
            Theme.of(context).colorScheme.secondary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          width: 1.w,
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40.r,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Icon(Icons.person, size: 40.w, color: Colors.white),
          ),
          SizedBox(height: 16.h),
          Text(
            'My Personal Assistant',
            style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8.h),
          Text(
            'AI-powered personal assistant',
            style: TextStyle(
              fontSize: 14.sp,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  // Notifications Settings Section
  Widget _buildNotificationSettings(
    BuildContext context,
    AppProvider appProvider,
  ) {
    bool notificationsEnabled =
        appProvider.settings['notificationsEnabled'] ?? true;
    bool voiceCallEnabled = appProvider.settings['voiceCallEnabled'] ?? true;

    return _buildSettingsSection(
      context,
      'Notifications',
      Icons.notifications,
      [
        _buildSwitchTile(
          context,
          'Enable Notifications',
          'Receive push notifications for events and reminders',
          notificationsEnabled,
          (value) async {
            await appProvider.updateSetting('notificationsEnabled', value);
            if (value) {
              await NotificationService.showNotification(
                title: 'Notifications Enabled',
                body: 'You will receive event and reminder notifications.',
              );
            }
          },
        ),
        _buildReminderTimePicker(context, appProvider),
        _buildSwitchTile(
          context,
          'Voice Call Notifications',
          'Receive phone call-like notifications for important reminders',
          voiceCallEnabled,
          (value) async {
            await appProvider.updateSetting('voiceCallEnabled', value);
            if (value) {
              await NotificationService.showNotification(
                title: 'Voice Call Notifications Enabled',
                body: 'You will receive call-like notifications for events.',
              );
            }
          },
        ),
        _buildDailyScheduleCallSettings(context, appProvider),
      ],
    );
  }

  Widget _buildDailyScheduleCallSettings(
    BuildContext context,
    AppProvider appProvider,
  ) {
    bool isEnabled = appProvider.settings['dailyScheduleCallEnabled'] ?? false;
    String callTime = appProvider.settings['dailyScheduleCallTime'] ?? '08:30';

    return Column(
      children: [
        _buildSwitchTile(
          context,
          'Daily Schedule Call',
          'Receive a daily call summarizing your events & calender',
          isEnabled,
          (value) async {
            await appProvider.updateSetting('dailyScheduleCallEnabled', value);
          },
        ),
        if (isEnabled)
          ListTile(
            title: Text(
              'Call Time',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Time for daily schedule summary call',
              style: TextStyle(fontSize: 14.sp),
            ),
            trailing: InkWell(
              borderRadius: BorderRadius.circular(8.r),
              onTap: () async {
                final TimeOfDay? pickedTime = await showTimePicker(
                  context: context,
                  initialTime: _parseTimeString(callTime),
                );
                if (pickedTime != null) {
                  String newTime =
                      '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
                  await appProvider.updateSetting(
                    'dailyScheduleCallTime',
                    newTime,
                  );
                }
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.2),
                    width: 1.w,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16.w,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      _formatTimeForDisplay(callTime),
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  TimeOfDay _parseTimeString(String timeString) {
    try {
      final parts = timeString.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (e) {
      // Return a default value if parsing fails
      return const TimeOfDay(hour: 8, minute: 30);
    }
  }

  String _formatTimeForDisplay(String timeString) {
    final parts = timeString.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    if (hour == 0) {
      return '12:${minute.toString().padLeft(2, '0')} AM';
    } else if (hour < 12) {
      return '$hour:${minute.toString().padLeft(2, '0')} AM';
    } else if (hour == 12) {
      return '12:${minute.toString().padLeft(2, '0')} PM';
    } else {
      return '${hour - 12}:${minute.toString().padLeft(2, '0')} PM';
    }
  }

  Widget _buildReminderTimePicker(
    BuildContext context,
    AppProvider appProvider,
  ) {
    int totalMinutes = appProvider.settings['reminderTime'] ?? 15;
    int hours = totalMinutes ~/ 60;
    int minutes = totalMinutes % 60;

    String displayTime() {
      if (hours > 0 && minutes > 0) {
        return '$hours hr${hours > 1 ? 's' : ''} $minutes min${minutes > 1 ? 's' : ''}';
      } else if (hours > 0) {
        return '$hours hr${hours > 1 ? 's' : ''}';
      } else {
        return '$minutes min${minutes > 1 ? 's' : ''}';
      }
    }

    return ListTile(
      title: Text(
        'Reminder Time',
        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        'How long before an event to send a reminder',
        style: TextStyle(fontSize: 14.sp),
      ),
      trailing: InkWell(
        borderRadius: BorderRadius.circular(8.r),
        onTap: () async {
          final result = await showModalBottomSheet<int>(
            context: context,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            ),
            builder: (context) {
              int tempHours = hours;
              int tempMinutes = minutes;
              return StatefulBuilder(
                builder: (context, setModalState) {
                  return Container(
                    padding: EdgeInsets.all(24.w),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Select Reminder Time',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 24.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Hours Picker
                            Column(
                              children: [
                                Text(
                                  'Hours',
                                  style: TextStyle(fontSize: 14.sp),
                                ),
                                SizedBox(height: 8.h),
                                DropdownButton<int>(
                                  value: tempHours,
                                  onChanged: (val) {
                                    setModalState(() => tempHours = val!);
                                  },
                                  items: List.generate(13, (i) => i)
                                      .map(
                                        (h) => DropdownMenuItem(
                                          value: h,
                                          child: Text('$h'),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ),
                            SizedBox(width: 12.w),
                            // Center ':' vertically between pickers
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(':', style: TextStyle(fontSize: 24.sp)),
                              ],
                            ),
                            SizedBox(width: 12.w),
                            // Minutes Picker
                            Column(
                              children: [
                                Text(
                                  'Minutes',
                                  style: TextStyle(fontSize: 14.sp),
                                ),
                                SizedBox(height: 8.h),
                                DropdownButton<int>(
                                  value: tempMinutes,
                                  onChanged: (val) {
                                    setModalState(() => tempMinutes = val!);
                                  },
                                  items:
                                      [
                                            0,
                                            5,
                                            10,
                                            15,
                                            20,
                                            25,
                                            30,
                                            35,
                                            40,
                                            45,
                                            50,
                                            55,
                                          ]
                                          .map(
                                            (m) => DropdownMenuItem(
                                              value: m,
                                              child: Text('$m'),
                                            ),
                                          )
                                          .toList(),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 24.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'Cancel',
                                style: TextStyle(fontSize: 14.sp),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(
                                  context,
                                  tempHours * 60 + tempMinutes,
                                );
                              },
                              child: Text(
                                'Save',
                                style: TextStyle(fontSize: 14.sp),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
          if (result != null) {
            await appProvider.updateSetting('reminderTime', result);
          }
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              width: 1.w,
            ),
          ),
          child: Text(
            displayTime(),
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  // Voice Settings Section
  Widget _buildVoiceSettings(BuildContext context, AppProvider appProvider) {
    return _buildSettingsSection(
      context,
      'Voice Settings',
      Icons.record_voice_over,
      [
        _buildDropdownTile(
          context,
          'Language',
          'Select voice language',
          ['en-US', 'en-GB', 'es-ES', 'fr-FR', 'de-DE'],
          appProvider.settings['voiceLanguage'] ?? 'en-US',
          (value) => appProvider.updateSetting('voiceLanguage', value),
        ),
        _buildDropdownTile(
          context,
          'Accent',
          'Select voice accent',
          ['American', 'British', 'Australian', 'Canadian'],
          appProvider.settings['voiceAccent'] ?? 'American',
          (value) => appProvider.updateSetting('voiceAccent', value),
        ),
        _buildDropdownTile(
          context,
          'Tone',
          'Select voice tone',
          ['Professional', 'Friendly', 'Casual', 'Formal'],
          appProvider.settings['voiceTone'] ?? 'Professional',
          (value) => appProvider.updateSetting('voiceTone', value),
        ),
      ],
    );
  }

  // Calendar Settings Section
  Widget _buildCalendarSettings(BuildContext context, AppProvider appProvider) {
    return _buildSettingsSection(context, 'Calendar', Icons.calendar_today, [
      _buildSwitchTile(
        context,
        'Google Calendar Sync',
        'Sync events with your Google Calendar',
        appProvider.settings['googleCalendarSync'] ?? true,
        (value) async {
          if (value) {
            // Ask for permission to import Google Calendar data
            final approved = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Import Google Calendar Data'),
                content: const Text(
                  'This app needs your permission to import and sync your Google Calendar events. Do you want to allow this?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Deny'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Allow'),
                  ),
                ],
              ),
            );
            if (approved == true) {
              // Enable Google Calendar sync
              final calendarProvider = Provider.of<CalendarProvider>(
                context,
                listen: false,
              );
              await calendarProvider.enableGoogleCalendar();
              appProvider.updateSetting('googleCalendarSync', true);
            } else {
              appProvider.updateSetting('googleCalendarSync', false);
            }
          } else {
            // Disable Google Calendar sync
            final calendarProvider = Provider.of<CalendarProvider>(
              context,
              listen: false,
            );
            await calendarProvider.disableGoogleCalendar();
            appProvider.updateSetting('googleCalendarSync', false);
          }
        },
      ),
    ]);
  }

  // Privacy & Location Settings Section
  Widget _buildPrivacySettings(BuildContext context, AppProvider appProvider) {
    return _buildSettingsSection(
      context,
      'Privacy & Location',
      Icons.privacy_tip,
      [
        _buildSwitchTile(
          context,
          'Location Access',
          'Allow location-based features and traffic updates',
          appProvider.settings['locationAccess'] ?? true,
          (value) async {
            await appProvider.updateSetting('locationAccess', value);
          },
        ),
        _buildListTile(
          context,
          'Current Location',
          appProvider.liveLocationDisplay,
          Icons.location_on,
          () async {
            await appProvider.refreshLocation();
          },
        ),
      ],
    );
  }

  Widget _buildUISettings(BuildContext context, AppProvider appProvider) {
    return _buildSettingsSection(context, 'Appearance', Icons.palette, [
      _buildSwitchTile(
        context,
        'Dark Mode',
        'Use dark theme',
        appProvider.isDarkMode,
        (value) async {
          await appProvider.toggleDarkMode(); // This updates Hive and state
        },
      ),
    ]);
  }

  void _showEnhancedModal(
    BuildContext context,
    String title,
    IconData icon,
    String content,
    String buttonText,
    String url,
    Color accentColor,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28.r),
        ),
        elevation: 16,
        child: Container(
          constraints: BoxConstraints(maxWidth: 400.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).colorScheme.surface
                    : Theme.of(context).colorScheme.primary.withOpacity(0.08),
                accentColor.withOpacity(0.12),
                Theme.of(context).colorScheme.secondary.withOpacity(0.10),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(28.r),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.15),
                blurRadius: 24.r,
                offset: Offset(0, 8.h),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(32.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64.w,
                  height: 64.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [accentColor, accentColor.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Icon(icon, size: 36.w, color: Colors.white),
                ),
                SizedBox(height: 24.h),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.h),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.open_in_new, color: Colors.white),
                    label: Text(
                      buttonText,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                    ),
                    onPressed: () async {
                      if (await canLaunchUrl(Uri.parse(url))) {
                        await launchUrl(
                          Uri.parse(url),
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                  ),
                ),
                SizedBox(height: 12.h),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Close', style: TextStyle(fontSize: 14.sp)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return _buildSettingsSection(context, 'About', Icons.info, [
      _buildListTile(
        context,
        'App Version',
        '1.0.0',
        Icons.app_settings_alt,
        null,
      ),
      _buildListTile(
        context,
        'Terms of Service',
        'Read our terms and conditions',
        Icons.description,
        () {
          _showEnhancedModal(
            context,
            'Terms of Service',
            Icons.description,
            'Welcome to your Personal Assistant! By using this app, you agree to our comprehensive terms and conditions. We value your privacy and security.',
            'Read Full Terms',
            'https://ai-personal-assistant-bice.vercel.app/terms',
            Colors.blueAccent,
          );
        },
      ),
      _buildListTile(
        context,
        'Privacy Policy',
        'Read our privacy policy',
        Icons.privacy_tip,
        () {
          _showEnhancedModal(
            context,
            'Privacy Policy',
            Icons.privacy_tip,
            'Your data is completely safe with us! We never share your personal information with third parties. Review our detailed privacy policy.',
            'View Privacy Policy',
            'https://ai-personal-assistant-bice.vercel.app/privacy',
            Colors.teal,
          );
        },
      ),
      _buildListTile(
        context,
        'Legal',
        'Legal information and disclaimers',
        Icons.gavel,
        () {
          _showEnhancedModal(
            context,
            'Legal Information',
            Icons.gavel,
            'Important legal information, disclaimers, and regulatory compliance details for your Personal Assistant app.',
            'View Legal Details',
            'https://ai-personal-assistant-bice.vercel.app/legal',
            Colors.deepOrange,
          );
        },
      ),
      _buildListTile(
        context,
        'Visit Us',
        'Learn more about our company',
        Icons.language,
        () {
          _showEnhancedModal(
            context,
            'Visit Our Website',
            Icons.language,
            'Discover more about our innovative AI solutions, company story, and the team behind your Personal Assistant.',
            'Visit Website',
            'https://ai-personal-assistant-bice.vercel.app/',
            Colors.deepPurple,
          );
        },
      ),
      _buildListTile(
        context,
        'Support',
        'Get help and contact support',
        Icons.help,
        () {
          _showEnhancedModal(
            context,
            'Support Center',
            Icons.help,
            'Need assistance? Our support team is here to help you get the most out of your Personal Assistant experience.',
            'Get Support',
            'https://ai-personal-assistant-bice.vercel.app/',
            Colors.green,
          );
        },
      ),
      _buildListTile(
        context,
        'Sign Out',
        'Sign out of your account',
        Icons.logout,
        () async {
          // Keep your existing sign out logic
          bool? shouldSignOut = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(
                  'Sign Out',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                content: Text(
                  'Are you sure you want to sign out?',
                  style: TextStyle(fontSize: 16.sp),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Sign Out'),
                  ),
                ],
              );
            },
          );

          if (shouldSignOut == true && mounted) {
            await context.read<AuthProvider>().signOut();
          }
        },
      ),
    ]);
  }

  Widget _buildSettingsSection(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 18.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.06),
            blurRadius: 8.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Accent bar (fills height)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 6.w,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(16.r),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: 6.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.all(20.w),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Icon(
                          icon,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20.w,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                ...children,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: () => onChanged(!value),
        child: ListTile(
          title: Text(
            title,
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(subtitle, style: TextStyle(fontSize: 14.sp)),
          trailing: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownTile(
    BuildContext context,
    String title,
    String subtitle,
    List<String> options,
    String currentValue,
    ValueChanged<String> onChanged,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: () {},
        child: ListTile(
          title: Text(
            title,
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(subtitle, style: TextStyle(fontSize: 14.sp)),
          trailing: DropdownButton<String>(
            value: currentValue,
            onChanged: (value) {
              if (value != null) {
                onChanged(value);
              }
            },
            items: options
                .map(
                  (option) => DropdownMenuItem(
                    value: option,
                    child: Text(option, style: TextStyle(fontSize: 14.sp)),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  // Example creative touch: Animated location icon
  Widget _buildListTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData trailingIcon,
    VoidCallback? onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: onTap,
        child: ListTile(
          title: Text(
            title,
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(subtitle, style: TextStyle(fontSize: 14.sp)),
          trailing: trailingIcon == Icons.location_on
              ? AnimatedSwitcher(
                  duration: Duration(milliseconds: 600),
                  child: Icon(
                    trailingIcon,
                    key: ValueKey(subtitle),
                    size: 20.w,
                    color: Colors.teal,
                  ),
                )
              : Icon(trailingIcon, size: 20.w),
        ),
      ),
    );
  }
}
