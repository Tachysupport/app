import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/calendar_event.dart';
import '../models/chat_message.dart';

class HiveStorageService {
  static Future<void> saveAllSettings(Map<String, dynamic> settings) async {
    if (_settingsBox == null) {
      throw Exception('Hive not initialized');
    }
    try {
      await _settingsBox!.clear();
      for (final entry in settings.entries) {
        await _settingsBox!.put(entry.key, {'value': entry.value});
      }
      debugPrint('Saved all settings to Hive');
    } catch (e) {
      debugPrint('Error saving all settings to Hive: $e');
      rethrow;
    }
  }

  static Future<void> deleteMessage(String messageId) async {
    if (_messagesBox == null) {
      throw Exception('Hive not initialized');
    }
    try {
      await _messagesBox!.delete(messageId);
      debugPrint('Deleted message $messageId from Hive');
    } catch (e) {
      debugPrint('Error deleting message from Hive: $e');
      rethrow;
    }
  }

  static const String _eventsBoxName = 'calendar_events';
  static const String _messagesBoxName = 'chat_messages';
  static const String _settingsBoxName = 'app_settings';

  static Box<CalendarEvent>? _eventsBox;
  static Box<ChatMessage>? _messagesBox;
  static Box<Map<dynamic, dynamic>>? _settingsBox;

  static Future<void> initialize() async {
    try {
      await Hive.initFlutter();

      // Register adapters
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(CalendarEventAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(ChatMessageAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(MessageTypeAdapter());
      }
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(MessageStatusAdapter());
      }

      // Open boxes
      _eventsBox = await Hive.openBox<CalendarEvent>(_eventsBoxName);
      _messagesBox = await Hive.openBox<ChatMessage>(_messagesBoxName);
      _settingsBox = await Hive.openBox<Map<dynamic, dynamic>>(
        _settingsBoxName,
      );

      debugPrint('Hive storage initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Hive storage: $e');
      rethrow;
    }
  }

  // Calendar Events Methods
  static Future<void> saveEvents(List<CalendarEvent> events) async {
    if (_eventsBox == null) {
      throw Exception('Hive not initialized');
    }

    try {
      await _eventsBox!.clear();
      for (final event in events) {
        await _eventsBox!.put(event.id, event);
      }
      debugPrint('Saved ${events.length} events to Hive');
    } catch (e) {
      debugPrint('Error saving events to Hive: $e');
      rethrow;
    }
  }

  static Future<List<CalendarEvent>> getEvents() async {
    if (_eventsBox == null) {
      throw Exception('Hive not initialized');
    }

    try {
      return _eventsBox!.values.toList();
    } catch (e) {
      debugPrint('Error getting events from Hive: $e');
      return [];
    }
  }

  static Future<void> addEvent(CalendarEvent event) async {
    if (_eventsBox == null) {
      throw Exception('Hive not initialized');
    }

    try {
      await _eventsBox!.put(event.id, event);
      debugPrint('Added event ${event.id} to Hive');
    } catch (e) {
      debugPrint('Error adding event to Hive: $e');
      rethrow;
    }
  }

  static Future<void> updateEvent(CalendarEvent event) async {
    if (_eventsBox == null) {
      throw Exception('Hive not initialized');
    }

    try {
      await _eventsBox!.put(event.id, event);
      debugPrint('Updated event ${event.id} in Hive');
    } catch (e) {
      debugPrint('Error updating event in Hive: $e');
      rethrow;
    }
  }

  static Future<void> deleteEvent(String eventId) async {
    if (_eventsBox == null) {
      throw Exception('Hive not initialized');
    }

    try {
      await _eventsBox!.delete(eventId);
      debugPrint('Deleted event $eventId from Hive');
    } catch (e) {
      debugPrint('Error deleting event from Hive: $e');
      rethrow;
    }
  }

  static Future<List<CalendarEvent>> getTodayEvents() async {
    final events = await getEvents();
    return events.where((event) => event.isToday).toList();
  }

  static Future<List<CalendarEvent>> getUpcomingEvents() async {
    final events = await getEvents();
    return events.where((event) => event.isUpcoming).toList();
  }

  static Future<List<CalendarEvent>> getEventsForDate(DateTime date) async {
    final events = await getEvents();
    return events.where((event) {
      return event.startTime.year == date.year &&
          event.startTime.month == date.month &&
          event.startTime.day == date.day;
    }).toList();
  }

  // Chat Messages Methods
  static Future<void> saveMessages(List<ChatMessage> messages) async {
    if (_messagesBox == null) {
      throw Exception('Hive not initialized');
    }

    try {
      await _messagesBox!.clear();
      for (final message in messages) {
        await _messagesBox!.put(message.id, message);
      }
      debugPrint('Saved ${messages.length} messages to Hive');
    } catch (e) {
      debugPrint('Error saving messages to Hive: $e');
      rethrow;
    }
  }

  static Future<List<ChatMessage>> getMessages() async {
    if (_messagesBox == null) {
      throw Exception('Hive not initialized');
    }

    try {
      return _messagesBox!.values.toList();
    } catch (e) {
      debugPrint('Error getting messages from Hive: $e');
      return [];
    }
  }

  static Future<void> addMessage(ChatMessage message) async {
    if (_messagesBox == null) {
      throw Exception('Hive not initialized');
    }

    try {
      await _messagesBox!.put(message.id, message);
      debugPrint('Added message ${message.id} to Hive');
    } catch (e) {
      debugPrint('Error adding message to Hive: $e');
      rethrow;
    }
  }

  static Future<void> deleteChat(String chatId) async {
    if (_messagesBox == null) {
      throw Exception('Hive not initialized');
    }
    try {
      final messagesToDelete = _messagesBox!.values
          .where((msg) => msg.chatId == chatId)
          .toList();
      for (final message in messagesToDelete) {
        await _messagesBox!.delete(message.id);
      }
      debugPrint('Deleted chat $chatId from Hive');
    } catch (e) {
      debugPrint('Error deleting chat from Hive: $e');
      rethrow;
    }
  }

  // Settings Methods
  static Future<void> saveSetting(String key, dynamic value) async {
    if (_settingsBox == null) {
      throw Exception('Hive not initialized');
    }

    try {
      await _settingsBox!.put(key, {
        'value': value,
        'timestamp': DateTime.now().toIso8601String(),
      });
      debugPrint('Saved setting $key to Hive');
    } catch (e) {
      debugPrint('Error saving setting to Hive: $e');
      rethrow;
    }
  }

  static Future<T?> getSetting<T>(String key, {T? defaultValue}) async {
    if (_settingsBox == null) {
      throw Exception('Hive not initialized');
    }

    try {
      final Map<dynamic, dynamic>? data = _settingsBox!.get(key);
      if (data != null && data['value'] != null) {
        return data['value'] as T;
      }
      return defaultValue;
    } catch (e) {
      debugPrint('Error getting setting from Hive: $e');
      return defaultValue;
    }
  }

  static Future<Map<String, dynamic>> getAllSettings() async {
    if (_settingsBox == null) {
      throw Exception('Hive not initialized');
    }

    try {
      final Map<String, dynamic> settings = {};
      for (final key in _settingsBox!.keys) {
        final Map<dynamic, dynamic>? data = _settingsBox!.get(key);
        if (data != null && data['value'] != null) {
          settings[key.toString()] = data['value'];
        }
      }
      return settings;
    } catch (e) {
      debugPrint('Error getting all settings from Hive: $e');
      return {};
    }
  }

  // Utility Methods
  static Future<void> clearAllData() async {
    try {
      await _eventsBox?.clear();
      await _messagesBox?.clear();
      await _settingsBox?.clear();
      debugPrint('Cleared all data from Hive');
    } catch (e) {
      debugPrint('Error clearing Hive data: $e');
      rethrow;
    }
  }

  static Future<int> getEventsCount() async {
    if (_eventsBox == null) return 0;
    return _eventsBox!.length;
  }

  static Future<int> getMessagesCount() async {
    if (_messagesBox == null) return 0;
    return _messagesBox!.length;
  }

  static Future<void> close() async {
    try {
      await _eventsBox?.close();
      await _messagesBox?.close();
      await _settingsBox?.close();
      debugPrint('Closed all Hive boxes');
    } catch (e) {
      debugPrint('Error closing Hive boxes: $e');
    }
  }
}
