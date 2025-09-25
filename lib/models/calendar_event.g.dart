// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_event.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CalendarEventAdapter extends TypeAdapter<CalendarEvent> {
  @override
  final int typeId = 0;

  @override
  CalendarEvent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CalendarEvent(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      startTime: fields[3] as DateTime,
      endTime: fields[4] as DateTime,
      location: fields[5] as String,
      isGoogleCalendarEvent: fields[7] as bool,
      googleEventId: fields[8] as String?,
      isCompleted: fields[9] as bool,
      notes: fields[10] as String?,
      reminderMinutes: fields[11] as int,
      recurrence: fields[12] as String,
      attachment: fields[13] as String,
      isAllDay: fields[14] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, CalendarEvent obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.startTime)
      ..writeByte(4)
      ..write(obj.endTime)
      ..writeByte(5)
      ..write(obj.location)
      ..writeByte(6)
      ..write(obj.colorValue)
      ..writeByte(7)
      ..write(obj.isGoogleCalendarEvent)
      ..writeByte(8)
      ..write(obj.googleEventId)
      ..writeByte(9)
      ..write(obj.isCompleted)
      ..writeByte(10)
      ..write(obj.notes)
      ..writeByte(11)
      ..write(obj.reminderMinutes)
      ..writeByte(12)
      ..write(obj.recurrence)
      ..writeByte(13)
      ..write(obj.attachment)
      ..writeByte(14)
      ..write(obj.isAllDay);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarEventAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
