import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'calendar_event.g.dart';

enum EventType { meeting, task, reminder, appointment }

@HiveType(typeId: 0)
class CalendarEvent extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final DateTime startTime;

  @HiveField(4)
  final DateTime endTime;

  @HiveField(5)
  final String location;

  @HiveField(6)
  final int colorValue;

  @HiveField(7)
  final bool isGoogleCalendarEvent;

  @HiveField(8)
  final String? googleEventId;

  @HiveField(9)
  final bool isCompleted;

  @HiveField(10)
  final String? notes;

  @HiveField(11)
  final int reminderMinutes;

  @HiveField(12)
  final String recurrence;

  @HiveField(13)
  final String attachment;

  @HiveField(14)
  final bool isAllDay;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    this.location = '',
    Color color = Colors.blue,
    this.isGoogleCalendarEvent = false,
    this.googleEventId,
    this.isCompleted = false,
    this.notes,
    this.reminderMinutes = 15,
    this.recurrence = 'Does not repeat',
    this.attachment = '',
    this.isAllDay = false,
  }) : colorValue = color.value;

  // Getter for color
  Color get color => Color(colorValue);

  CalendarEvent copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    Color? color,
    bool? isGoogleCalendarEvent,
    String? googleEventId,
    bool? isCompleted,
    String? notes,
    int? reminderMinutes,
    String? recurrence,
    String? attachment,
    bool? isAllDay,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      color: color ?? this.color,
      isGoogleCalendarEvent:
          isGoogleCalendarEvent ?? this.isGoogleCalendarEvent,
      googleEventId: googleEventId ?? this.googleEventId,
      isCompleted: isCompleted ?? this.isCompleted,
      notes: notes ?? this.notes,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      recurrence: recurrence ?? this.recurrence,
      attachment: attachment ?? this.attachment,
      isAllDay: isAllDay ?? this.isAllDay,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'location': location,
      'color': color.value,
      'isGoogleCalendarEvent': isGoogleCalendarEvent,
      'googleEventId': googleEventId,
      'isCompleted': isCompleted,
      'notes': notes,
      'reminderMinutes': reminderMinutes,
      'recurrence': recurrence,
      'attachment': attachment,
      'isAllDay': isAllDay,
    };
  }

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      location: json['location'] ?? '',
      color: Color(json['color'] ?? Colors.blue.value),
      isGoogleCalendarEvent: json['isGoogleCalendarEvent'] ?? false,
      googleEventId: json['googleEventId'],
      isCompleted: json['isCompleted'] ?? false,
      notes: json['notes'],
      reminderMinutes: json['reminderMinutes'] ?? 15,
      recurrence: json['recurrence'] ?? 'Does not repeat',
      attachment: json['attachment'] ?? '',
      isAllDay: json['isAllDay'] ?? false,
    );
  }

  Duration get duration => endTime.difference(startTime);

  bool get isToday {
    final now = DateTime.now();
    return startTime.year == now.year &&
        startTime.month == now.month &&
        startTime.day == now.day;
  }

  bool get isUpcoming {
    return startTime.isAfter(DateTime.now());
  }

  bool get isOverdue {
    return endTime.isBefore(DateTime.now()) && !isCompleted;
  }

  String get timeRange {
    return '${_formatTime(startTime)} - ${_formatTime(endTime)}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
