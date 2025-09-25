import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'chat_message.g.dart';

enum MessageType { user, assistant }

enum MessageStatus { sending, sent, delivered, read, failed }

@HiveType(typeId: 1)
class ChatMessage extends HiveObject {
  Map<String, dynamic> toMap() {
    return toJson();
  }

  static ChatMessage fromMap(Map<String, dynamic> map) {
    return ChatMessage.fromJson(map);
  }
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String content;

  @HiveField(2)
  final MessageType type;

  @HiveField(3)
  final DateTime timestamp;

  @HiveField(4)
  final MessageStatus status;

  @HiveField(5)
  final bool isVoiceMessage;

  @HiveField(6)
  final int? voiceDurationSeconds;

  @HiveField(7)
  final String? relatedEventId;

  @HiveField(8)
  final Map<String, dynamic>? metadata;

  @HiveField(9)
  final String chatId;

  ChatMessage({
    required this.id,
    required this.chatId,
    required this.content,
    required this.type,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.isVoiceMessage = false,
    Duration? voiceDuration,
    this.relatedEventId,
    this.metadata,
  }) : voiceDurationSeconds = voiceDuration?.inSeconds;

  // Getter for voice duration
  Duration? get voiceDuration => voiceDurationSeconds != null
      ? Duration(seconds: voiceDurationSeconds!)
      : null;

  ChatMessage copyWith({
    String? id,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    MessageStatus? status,
    bool? isVoiceMessage,
    Duration? voiceDuration,
    String? relatedEventId,
    Map<String, dynamic>? metadata,
    String? chatId,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      isVoiceMessage: isVoiceMessage ?? this.isVoiceMessage,
      voiceDuration: voiceDuration ?? this.voiceDuration,
      relatedEventId: relatedEventId ?? this.relatedEventId,
      metadata: metadata ?? this.metadata,
      chatId: chatId ?? this.chatId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'type': type.index,
      'timestamp': timestamp.toIso8601String(),
      'status': status.index,
      'isVoiceMessage': isVoiceMessage,
      'voiceDuration': voiceDuration?.inSeconds,
      'relatedEventId': relatedEventId,
      'metadata': metadata,
      'chatId': chatId,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      content: json['content'],
      type: MessageType.values[json['type']],
      timestamp: DateTime.parse(json['timestamp']),
      status: MessageStatus.values[json['status'] ?? 1],
      isVoiceMessage: json['isVoiceMessage'] ?? false,
      voiceDuration: json['voiceDuration'] != null
          ? Duration(seconds: json['voiceDuration'])
          : null,
      relatedEventId: json['relatedEventId'],
      metadata: json['metadata'],
      chatId: json['chatId'],
    );
  }

  bool get isUser => type == MessageType.user;
  bool get isAssistant => type == MessageType.assistant;

  String get timeString {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  bool get isToday {
    final now = DateTime.now();
    return timestamp.year == now.year &&
        timestamp.month == now.month &&
        timestamp.day == now.day;
  }

  String get displayTime {
    if (isToday) {
      return timeString;
    } else {
      return '${timestamp.day}/${timestamp.month} $timeString';
    }
  }

  IconData get statusIcon {
    switch (status) {
      case MessageStatus.sending:
        return Icons.schedule;
      case MessageStatus.sent:
        return Icons.check;
      case MessageStatus.delivered:
        return Icons.done_all;
      case MessageStatus.read:
        return Icons.done_all;
      case MessageStatus.failed:
        return Icons.error;
    }
  }

  Color get statusColor {
    switch (status) {
      case MessageStatus.sending:
        return Colors.grey;
      case MessageStatus.sent:
        return Colors.grey;
      case MessageStatus.delivered:
        return Colors.grey;
      case MessageStatus.read:
        return Colors.blue;
      case MessageStatus.failed:
        return Colors.red;
    }
  }
}

class MessageTypeAdapter extends TypeAdapter<MessageType> {
  @override
  final int typeId = 2;

  @override
  MessageType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MessageType.user;
      case 1:
        return MessageType.assistant;
      default:
        return MessageType.user;
    }
  }

  @override
  void write(BinaryWriter writer, MessageType obj) {
    switch (obj) {
      case MessageType.user:
        writer.writeByte(0);
        break;
      case MessageType.assistant:
        writer.writeByte(1);
        break;
    }
  }
}

class MessageStatusAdapter extends TypeAdapter<MessageStatus> {
  @override
  final int typeId = 3;

  @override
  MessageStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MessageStatus.sending;
      case 1:
        return MessageStatus.sent;
      case 2:
        return MessageStatus.delivered;
      case 3:
        return MessageStatus.read;
      case 4:
        return MessageStatus.failed;
      default:
        return MessageStatus.sent;
    }
  }

  @override
  void write(BinaryWriter writer, MessageStatus obj) {
    switch (obj) {
      case MessageStatus.sending:
        writer.writeByte(0);
        break;
      case MessageStatus.sent:
        writer.writeByte(1);
        break;
      case MessageStatus.delivered:
        writer.writeByte(2);
        break;
      case MessageStatus.read:
        writer.writeByte(3);
        break;
      case MessageStatus.failed:
        writer.writeByte(4);
        break;
    }
  }
}
