import 'package:flutter_tts/flutter_tts.dart';
import '../models/calendar_event.dart';

class TtsService {
  static String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $ampm';
  }

  static String generateEventBriefing({
    required String userName,
    required CalendarEvent event,
  }) {
    final startStr = TtsService._formatTime(event.startTime);
    final endStr = TtsService._formatTime(event.endTime);
    final location = event.location.isNotEmpty ? event.location : 'not specified';
    final details = event.description.isNotEmpty ? event.description : 'No details provided.';
    return "$userName, here's your event briefing: '${event.title}' at $startStr, ending at $endStr. The Location is $location. Details: $details. If you need anything else, just ask!";
  }
  /// Generates an advanced, creative audio briefing for the user's daily schedule
  static String generateAdvancedScheduleBriefing({
    required String userName,
    required List<dynamic> events, // List<CalendarEvent>
    DateTime? now,
  }) {
    now ??= DateTime.now();
    String greeting;
    if (now.hour < 5) {
      greeting = 'Good night';
    } else if (now.hour < 12) {
      greeting = 'Good morning';
    } else if (now.hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    StringBuffer briefing = StringBuffer();
    briefing.writeln('$greeting, $userName! Here is your personalized schedule briefing for today:');

    if (events.isEmpty) {
      briefing.writeln("You have no events scheduled for today. Enjoy your free time! If you need anything, just ask.");
    } else {
      briefing.writeln("You have ${events.length} event${events.length == 1 ? '' : 's'} today.");
      for (int i = 0; i < events.length; i++) {
        final event = events[i];
        final start = event.startTime;
        final end = event.endTime;
        final startStr = TtsService._formatTime(start);
        final endStr = TtsService._formatTime(end);
        briefing.writeln("At $endStr you have, '${event.title}', starting at $startStr, and ending at $endStr. The Location is ${event.location.isNotEmpty ? event.location : 'not specified'}. Details: ${event.description.isNotEmpty ? event.description : 'No details provided.'}");
        if (i < events.length - 1) {
          final nextEvent = events[i + 1];
          final nextStartStr = TtsService._formatTime(nextEvent.startTime);
          briefing.writeln("Next event is at $nextStartStr.");
        }
      }
      briefing.writeln("If you need to reschedule or want more details, just let me know. I'm here to help you stay organized and on track today.");
    }

    briefing.writeln("Wishing you a productive, joyful, and organized day! Your assistant is always here for you.");
    return briefing.toString();
  }

  // ...existing code...
  static final FlutterTts _tts = FlutterTts();

  static Future<void> speak(String text) async {
    await _tts.setLanguage('en-US');
    await _tts.setPitch(1.1); // Slightly higher pitch for warmth
    await _tts.setSpeechRate(0.45); // Slower rate for clarity
    await _tts.setVolume(1.0);
    await _tts.setVoice({'name': 'een-us-x-iom-local', 'locale': 'en-US'}); // Use a more natural voice if available
    // Add natural pauses for lists and sentences
    String processedText = text.replaceAll('. ', '. \n').replaceAll(', ', ', \n');
    await _tts.speak(processedText);
  }

  static Future<void> stop() async {
    await _tts.stop();
  }
}
