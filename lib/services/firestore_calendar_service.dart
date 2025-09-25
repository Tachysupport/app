import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';
import '../models/calendar_event.dart';

class FirestoreCalendarService {
  static final _collection = FirebaseFirestore.instance.collection('calendar_events');

  static Future<void> addEvent(CalendarEvent event) async {
    await _collection.doc(event.id).set(event.toJson());
  }

  static Future<void> updateEvent(CalendarEvent event) async {
    await _collection.doc(event.id).update(event.toJson());
  }

  static Future<void> deleteEvent(String eventId) async {
    await _collection.doc(eventId).delete();
  }

  static Future<List<CalendarEvent>> fetchEvents() async {
    final snapshot = await _collection.get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return CalendarEvent(
        id: data['id'],
        title: data['title'],
        description: data['description'],
        startTime: DateTime.parse(data['startTime']),
        endTime: DateTime.parse(data['endTime']),
        location: data['location'] ?? '',
        color: Color(data['colorValue'] ?? 0xFF2196F3),
        isGoogleCalendarEvent: data['isGoogleCalendarEvent'] ?? false,
        googleEventId: data['googleEventId'],
        isCompleted: data['isCompleted'] ?? false,
        notes: data['notes'],
        reminderMinutes: data['reminderMinutes'] ?? 15,
        recurrence: data['recurrence'] ?? 'Does not repeat',
        attachment: data['attachment'] ?? '',
        isAllDay: data['isAllDay'] ?? false,
      );
    }).toList();
  }
}
