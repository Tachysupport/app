import 'package:flutter/material.dart';
import '../services/hive_storage_service.dart';
import '../services/firestore_settings_service.dart';
import '../constants/app_theme.dart';
import '../utils/location_service.dart';
import '../main.dart';

class AppProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  bool _isLoading = false;
  String _currentLocation = 'Loading location...';
  Map<String, dynamic> _settings = {};

  bool get isDarkMode => _isDarkMode;
  bool get isLoading => _isLoading;
  String get currentLocation => _currentLocation;
  Map<String, dynamic> get settings => _settings;
  String get liveLocationDisplay {
    if (_settings['locationAccess'] == false) {
      return 'Location access disabled';
    }
    return _currentLocation;
  }

  ThemeData get theme => _isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme;

  AppProvider() {
    _loadSettings();
    _loadCurrentLocation();
  }

  Future<void> _loadSettings() async {
    _setLoading(true);
    try {
      // Load settings from Hive
      final hiveSettings = await HiveStorageService.getAllSettings();
      // Load settings from Firestore
      final firestoreSettings = await FirestoreSettingsService.getSettings();
      // Merge settings: Firestore takes precedence if conflict
      final mergedSettings = {...hiveSettings, ...firestoreSettings};
      _settings = mergedSettings;
      _isDarkMode = mergedSettings['darkMode'] ?? false;
      _currentLocation =
          mergedSettings['currentLocation'] ?? 'Loading location...';
      // Save merged settings back to Hive and Firestore for consistency
      await HiveStorageService.saveAllSettings(mergedSettings);
      await FirestoreSettingsService.saveSettings(mergedSettings);
    } catch (e) {
      debugPrint('Error loading settings from Hive/Firestore: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadCurrentLocation() async {
    try {
      String location = await LocationService.getCurrentLocation();
      _currentLocation = location;
      await HiveStorageService.saveSetting('currentLocation', location);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading current location: $e');
      _currentLocation = 'Unable to get location';
      notifyListeners();
    }
  }

  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    _settings['darkMode'] = _isDarkMode;
    await HiveStorageService.saveSetting('darkMode', _isDarkMode);
    await FirestoreSettingsService.updateSetting('darkMode', _isDarkMode);
    notifyListeners();
  }

  Future<void> updateSetting(String key, dynamic value) async {
    _settings[key] = value;
    await HiveStorageService.saveSetting(key, value);
    await FirestoreSettingsService.updateSetting(key, value);

    // Trigger notification reschedule for notification-related settings
    if (key == 'notificationsEnabled' ||
        key == 'voiceCallEnabled' ||
        key == 'dailyScheduleCallEnabled' ||
        key == 'dailyScheduleCallTime') {
      final context = navigatorKey.currentContext;
      if (context != null) {
        rescheduleAllEventNotifications(context);
      }
    }
    notifyListeners();
  }

  // Removed: _saveSetting, now using HiveStorageService for all settings

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  Future<void> refreshLocation() async {
    await _loadCurrentLocation();
    // Optionally sync location to Firestore
    await FirestoreSettingsService.updateSetting(
      'currentLocation',
      _currentLocation,
    );
  }
}
