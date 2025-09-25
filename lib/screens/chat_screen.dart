import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/chat_message.dart';
import '../services/hive_storage_service.dart';
import '../services/firestore_chat_service.dart';
import '../services/deepseek_service.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../providers/calendar_provider.dart';
import '../models/calendar_event.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  void _stopAudioPlayback() {
    _flutterTts.stop();
      if (mounted) {
        setState(() {
          _audioPlayingMessageId = null;
        });
      }
  }
  final FlutterTts _flutterTts = FlutterTts();
  String? _audioPlayingMessageId; // Track which message is playing audio
  final DeepSeekService _deepSeekService = DeepSeekService();
  String _userName = 'there';
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  List<Map<String, Object>> _chatHistory = [];
  bool _isTyping = false;
  bool _showSidebar = false;
  String _currentChatId = 'new';
  String _currentChatTitle = 'New Chat';
  late AnimationController _sidebarController;
  List<String> _displayedQuickActions = [];
  late DateTime _now;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _ticker = Ticker((_) {
      final now = DateTime.now();
      if (_now.minute != now.minute) {
        setState(() => _now = now);
      }
    })..start();
    _sidebarController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadUserName();
    _loadTodayChatOrNew();
    _loadQuickActions();
    _loadChatHistory();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _sidebarController.dispose();
    _flutterTts.stop();
    _audioPlayingMessageId = null;
    super.dispose();
  }

  Future<void> _loadUserName() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final name = await authProvider.getUserDisplayName();
      if (mounted) {
        setState(() {
          _userName = name;
        });
      }
  }

  Future<void> _loadChatHistory() async {
    // Fetch messages from both Hive and Firestore
    final hiveMessages = await HiveStorageService.getMessages();
    final firestoreMessages = await FirestoreChatService.getMessages();
    // Merge messages by id (prefer Firestore if duplicate)
    final Map<String, ChatMessage> mergedMap = {
      for (var m in hiveMessages) m.id: m,
      for (var m in firestoreMessages) m.id: m,
    };
    final mergedMessages = mergedMap.values.toList();
    // Group by chatId
    final Map<String, List<ChatMessage>> chats = {};
    for (final message in mergedMessages) {
      if (!chats.containsKey(message.chatId)) {
        chats[message.chatId] = [];
      }
      chats[message.chatId]!.add(message);
    }
    final sortedChats = chats.entries.toList()
      ..sort((a, b) {
        final lastMessageA = a.value.last.timestamp;
        final lastMessageB = b.value.last.timestamp;
        return lastMessageB.compareTo(lastMessageA);
      });
      if (mounted) {
        setState(() {
          _chatHistory = sortedChats.map((entry) {
            final firstMessage = entry.value.first;
            final lastMessage = entry.value.last;
            return <String, Object>{
              'id': entry.key,
              'title': firstMessage.content,
              'lastMessage': lastMessage.content,
              'timestamp': lastMessage.timestamp,
              'messageCount': entry.value.length,
              'isActive': false,
            };
          }).toList();
        });
      }
  }

  void _loadTodayChatOrNew() {
    _startNewChat();
  }

  void _loadQuickActions() {
    _displayedQuickActions = [
      'What’s my next meeting?',
      'Add a new event',
      'Show today’s schedule',
      'Reschedule my next meeting',
    ];
  }

  void _startNewChat() {
    _stopAudioPlayback();
      if (mounted) {
        setState(() {
          _messages.clear();
          _currentChatId = 'new';
          _currentChatTitle = 'New Chat';
          _showSidebar = false;
        });
      }
    if (_sidebarController.isCompleted) {
      _sidebarController.reverse();
    }
  }

  void _loadChat(String chatId) async {
    _stopAudioPlayback();
    if (chatId == 'new') {
      _startNewChat();
      return;
    }
    final allMessages = await HiveStorageService.getMessages();
    final chatMessages =
        allMessages.where((msg) => msg.chatId == chatId).toList();
    chatMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(chatMessages);
          _currentChatId = chatId;
          _currentChatTitle =
              chatMessages.isNotEmpty ? chatMessages.first.content : 'Chat';
          _showSidebar = false;
        });
      }
    _scrollToBottom();
    if (_sidebarController.isCompleted) {
      _sidebarController.reverse();
    }
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // If it's a new chat, set the chatId for the first message
    if (_currentChatId == 'new') {
      _currentChatId = DateTime.now().millisecondsSinceEpoch.toString();
      _currentChatTitle = message; // Use first message as title
    }

    final chatMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      chatId: _currentChatId, // Assign current chat ID
      content: message,
      type: MessageType.user,
      timestamp: DateTime.now(),
    );

    _addMessage(chatMessage);
    _messageController.clear();
    _getAssistantResponse(message);
  }

  void _addMessage(ChatMessage message) {
    if (mounted) {
      setState(() {
        _messages.add(message);
        _updateChatHistory(message);
      });
    }
    _scrollToBottom();
    HiveStorageService.addMessage(message);
    FirestoreChatService.addMessage(message);
  }

  void _updateChatHistory(ChatMessage message) {
    final existingChatIndex =
        _chatHistory.indexWhere((chat) => chat['id'] == message.chatId);

    if (existingChatIndex != -1) {
      // If chat already exists, update it and move it to the top
      final existingChat = _chatHistory.removeAt(existingChatIndex);
      existingChat['lastMessage'] = message.content;
      existingChat['timestamp'] = message.timestamp;
      existingChat['messageCount'] = ((existingChat['messageCount'] as int? ?? 1) + 1);
      _chatHistory.insert(0, existingChat);
    } else {
      // If it's a new chat, create a new entry and add it to the top
      _chatHistory.insert(0, <String, Object>{
        'id': message.chatId,
        'title': _currentChatTitle, // Title is set when chat starts
        'lastMessage': message.content,
        'timestamp': message.timestamp,
        'messageCount': 1,
        'isActive': true, // The new chat is the active one
      });
    }
  }

  Future<void> _getAssistantResponse(String userMessage) async {
    // Event CRUD intent detection
    final calendarProvider = Provider.of<CalendarProvider>(context, listen: false);
    final addEventRegex = RegExp(r'(add|create|schedule)\s+(event|meeting|appointment|task)?\s*(?:called|named)?\s*([\w\s]+)?\s*(at|on)?\s*([\w\s:]+)?', caseSensitive: false);
    final deleteEventRegex = RegExp(r'(delete|remove|cancel)\s+(event|meeting|appointment|task)?\s*(?:called|named)?\s*([\w\s]+)', caseSensitive: false);
    final updateEventRegex = RegExp(r'(update|edit|change)\s+(event|meeting|appointment|task)?\s*(?:called|named)?\s*([\w\s]+)\s*(to|at|on)?\s*([\w\s:]+)?', caseSensitive: false);

    // Add Event
    if (addEventRegex.hasMatch(userMessage)) {
      final match = addEventRegex.firstMatch(userMessage);
      final title = match?.group(3)?.trim() ?? 'Untitled Event';
      final timeStr = match?.group(5)?.trim() ?? '';
      DateTime? eventTime;
      if (timeStr.isNotEmpty) {
        // Try to parse time (simple formats)
        try {
          eventTime = DateTime.tryParse(timeStr) ?? DateTime.now();
        } catch (_) {
          eventTime = DateTime.now();
        }
      } else {
        eventTime = DateTime.now();
      }
      final newEvent = CalendarEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        description: '',
        startTime: eventTime,
        endTime: eventTime.add(const Duration(hours: 1)),
        location: '',
        isCompleted: false,
      );
      await calendarProvider.addEvent(newEvent);
      final assistantMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        chatId: _currentChatId,
        content: "Event '$title' scheduled for ${eventTime.toLocal()}.",
        type: MessageType.assistant,
        timestamp: DateTime.now(),
      );
      _addMessage(assistantMessage);
      setState(() { _isTyping = false; });
      return;
    }

    // Delete Event
    if (deleteEventRegex.hasMatch(userMessage)) {
      final match = deleteEventRegex.firstMatch(userMessage);
      final title = match?.group(3)?.trim() ?? '';
      final events = calendarProvider.events.where((e) => e.title.toLowerCase() == title.toLowerCase()).toList();
      if (events.isNotEmpty) {
        await calendarProvider.deleteEvent(events.first.id);
        final assistantMessage = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          chatId: _currentChatId,
          content: "Event '$title' deleted.",
          type: MessageType.assistant,
          timestamp: DateTime.now(),
        );
        _addMessage(assistantMessage);
      } else {
        final assistantMessage = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          chatId: _currentChatId,
          content: "No event found with the title '$title'.",
          type: MessageType.assistant,
          timestamp: DateTime.now(),
        );
        _addMessage(assistantMessage);
      }
      setState(() { _isTyping = false; });
      return;
    }

    // Update Event
    if (updateEventRegex.hasMatch(userMessage)) {
      final match = updateEventRegex.firstMatch(userMessage);
      final title = match?.group(3)?.trim() ?? '';
      final newTimeStr = match?.group(5)?.trim() ?? '';
      final events = calendarProvider.events.where((e) => e.title.toLowerCase() == title.toLowerCase()).toList();
      if (events.isNotEmpty && newTimeStr.isNotEmpty) {
        DateTime? newTime;
        try {
          newTime = DateTime.tryParse(newTimeStr) ?? events.first.startTime;
        } catch (_) {
          newTime = events.first.startTime;
        }
        final updatedEvent = events.first.copyWith(startTime: newTime);
        await calendarProvider.updateEvent(updatedEvent);
        final assistantMessage = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          chatId: _currentChatId,
          content: "Event '$title' updated to ${newTime.toLocal()}.",
          type: MessageType.assistant,
          timestamp: DateTime.now(),
        );
        _addMessage(assistantMessage);
      } else {
        final assistantMessage = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          chatId: _currentChatId,
          content: "Could not update event '$title'. Please check the event name and new time.",
          type: MessageType.assistant,
          timestamp: DateTime.now(),
        );
        _addMessage(assistantMessage);
      }
      setState(() { _isTyping = false; });
      return;
    }
    setState(() {
      _isTyping = true;
    });

    // Basic intent detection for greetings, thanks, and casual chat
    final lowerMsg = userMessage.trim().toLowerCase();
    final isGreeting = [
      'hello', 'hi', 'hey', 'good morning', 'good afternoon', 'good evening', 'greetings'
    ].any((greet) => lowerMsg.contains(greet));
    final isThanks = lowerMsg.contains('thank');
    final isFarewell = [
      'bye', 'goodbye', 'see you', 'later'
    ].any((farewell) => lowerMsg.contains(farewell));

    String prompt;
    if (isGreeting) {
      prompt = "You are my personal assistant. Reply to the user's greeting in a friendly, conversational way. Do not mention the calendar unless asked.";
    } else if (isThanks) {
      prompt = "You are my personal assistant. Reply to the user's gratitude in a warm, conversational way. Do not mention the calendar unless asked.";
    } else if (isFarewell) {
      prompt = "You are my personal assistant. Reply to the user's farewell in a friendly, conversational way. Do not mention the calendar unless asked.";
    } else {
      // Only add calendar context if the message is about schedule/events
      final isScheduleRequest = [
        'schedule', 'event', 'meeting', 'agenda', 'plan', 'reminder', 'today', 'upcoming'
      ].any((kw) => lowerMsg.contains(kw));
      String calendarContext = '';
      if (isScheduleRequest) {
        final todayEvents = await HiveStorageService.getTodayEvents();
        final upcomingEvents = await HiveStorageService.getUpcomingEvents();
        if (todayEvents.isNotEmpty) {
          calendarContext +=
              'Today\'s events: ${todayEvents.map((e) => '${e.title} at ${e.startTime.hour}:${e.startTime.minute.toString().padLeft(2, '0')}').join(', ')}. ';
        }
        if (upcomingEvents.isNotEmpty) {
          calendarContext +=
              'Upcoming events: ${upcomingEvents.map((e) => '${e.title} on ${e.startTime.month}/${e.startTime.day}').join(', ')}. ';
        }
      }
      prompt = "You are my personal assistant, always helpful and proactive. My name is $_userName. $calendarContext Please answer: '$userMessage' and offer any helpful suggestions or reminders.";
    }

    try {
      final response = await _deepSeekService.getDeepSeekResponse(prompt);
      if (mounted) {
        final assistantMessage = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          chatId:
              _currentChatId, // Ensure assistant response is part of the same chat
          content: response,
          type: MessageType.assistant,
          timestamp: DateTime.now(),
        );
        _addMessage(assistantMessage);
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          chatId:
              _currentChatId, // Ensure error message is part of the same chat
          content: 'Sorry, I could not connect to the assistant.',
          type: MessageType.assistant,
          timestamp: DateTime.now(),
        );
        _addMessage(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
      }
    }
  }

  void _handleQuickAction(String action) {
    _messageController.text = action;
    _sendMessage();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showChatOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 16.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary.withOpacity(0.07),
                Theme.of(context).colorScheme.secondary.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                title: Text('Clear Chat', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _clearChat();
                },
              ),
              ListTile(
                leading: Icon(Icons.schedule, color: Theme.of(context).colorScheme.primary),
                title: Text('Request Schedule Briefing', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _getAssistantResponse('Please provide a detailed briefing of my schedule for today.');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error, size: 32.w),
              SizedBox(height: 16.h),
              Text('Clear Chat', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600)),
              SizedBox(height: 12.h),
              Text('Are you sure you want to clear all messages in this chat?', style: TextStyle(fontSize: 14.sp)),
              SizedBox(height: 24.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: TextStyle(fontSize: 14.sp)),
                  ),
                  SizedBox(width: 8.w),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                    onPressed: () async {
                      await HiveStorageService.deleteChat(_currentChatId);
                      await FirestoreChatService.deleteChat(_currentChatId);
                      setState(() {
                        _messages.clear();
                        _chatHistory.removeWhere((chat) => chat['id'] == _currentChatId);
                      });
                      _startNewChat();
                      Navigator.pop(context);
                    },
                    child: Text('Clear', style: TextStyle(fontSize: 14.sp)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteChatDialog(String chatId, String chatTitle) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error, size: 32.w),
              SizedBox(height: 16.h),
              Text('Delete Chat', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600)),
              SizedBox(height: 12.h),
              Text('Are you sure you want to delete "$chatTitle"? This action cannot be undone.', style: TextStyle(fontSize: 14.sp)),
              SizedBox(height: 24.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: TextStyle(fontSize: 14.sp)),
                  ),
                  SizedBox(width: 8.w),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      await HiveStorageService.deleteChat(chatId);
                      await FirestoreChatService.deleteChat(chatId);
                      _loadChatHistory();
                      if (_currentChatId == chatId) {
                        _startNewChat();
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Chat "$chatTitle" deleted', style: TextStyle(fontSize: 14.sp)),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Text('Delete', style: TextStyle(fontSize: 14.sp)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _buildMainChatArea()),
          if (_showSidebar) ...[
            // Overlay for closing sidebar
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  _sidebarController.reverse();
                  setState(() => _showSidebar = false);
                },
                child: Container(
                  color: Colors.black.withOpacity(0.18),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: SizedBox(
                width: 250.w,
                child: _buildSidebar(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(-1, 0),
        end: Offset.zero,
      ).animate(_sidebarController),
      child: Container(
        width: 250.w,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            right: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
        ),
        child: Column(
          children: [
            AppBar(
              title: Text('Chat History', style: TextStyle(fontSize: 16.sp)),
              leading: IconButton(
                icon: Icon(Icons.close, size: 20.w),
                onPressed: () {
                  _sidebarController.reverse();
                  setState(() {
                    _showSidebar = false;
                  });
                },
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.add_comment_outlined, size: 20.w),
                  onPressed: _startNewChat,
                ),
              ],
            ),
            Container(
              margin: EdgeInsets.all(12.w),
              child: ElevatedButton.icon(
                onPressed: _startNewChat,
                icon: Icon(Icons.add, size: 16.w),
                label: Text(
                  'New Chat',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: 18.w,
                    vertical: 14.h,
                  ),
                  foregroundColor: Colors.white,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  elevation: 4,
                  shadowColor:
                      Theme.of(context).colorScheme.primary.withOpacity(0.25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 6.w),
                itemCount: _chatHistory.length,
                itemBuilder: (context, index) {
                  final chat = _chatHistory[index];
                  final isActive = chat['id'] == _currentChatId;
                  return Container(
                    margin: EdgeInsets.only(bottom: 6.h),
                    decoration: BoxDecoration(
                      gradient: isActive
                          ? LinearGradient(
                              colors: [
                                Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.12),
                                Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.07),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            )
                          : null,
                      color: isActive
                          ? null
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12.r),
                      border: isActive
                          ? Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.3),
                              width: 1.2.w,
                            )
                          : Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withOpacity(0.08),
                              width: 1.w,
                            ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12.r),
                        onTap: () => _loadChat(chat['id'] as String),
                        onLongPress: () => _showDeleteChatDialog(chat['id'] as String, chat['title'] as String),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                chat['title'] as String,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                  color: isActive
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                chat['lastMessage'] as String,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.7),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                _formatTimestamp(chat['timestamp'] as DateTime),
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainChatArea() {
    return Column(
      children: [
        _buildAppBar(),
        Expanded(
          child: (_messages.isEmpty)
              ? _buildWelcomeSection()
              : _buildMessagesList(),
        ),
        _buildInputArea(),
      ],
    );
  }

  Widget _buildAppBar() {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _currentChatTitle,
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600),
          ),
          Text(
            DateFormat('EEEE, MMMM d, h:mm a').format(_now),
            style: TextStyle(fontSize: 12.sp, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
          ),
        ],
      ),
      leading: IconButton(
        icon: Icon(Icons.menu, size: 24.w),
        onPressed: () {
          setState(() {
            _showSidebar = !_showSidebar;
          });
          if (_showSidebar) {
            _sidebarController.forward();
          } else {
            _sidebarController.reverse();
          }
        },
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.more_vert, size: 24.w),
          onPressed: () => _showChatOptions(context),
        ),
      ],
    );
  }

  Widget _buildWelcomeSection() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          Container(
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
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 24.r,
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/ai_avatar_small.png',
                      width: 48.w,
                      height: 48.w,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  'Hello, $_userName! How can I help?',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'Quick Actions',
            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 12.h),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8.w,
              mainAxisSpacing: 8.h,
              childAspectRatio: 2.5,
            ),
            itemCount: _displayedQuickActions.length,
            itemBuilder: (context, index) {
              return _buildQuickActionCard(_displayedQuickActions[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(String action) {
    // Assign a unique color/gradient and icon for each quick action
    final List<List<Color>> gradients = [
      [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary],
      [Colors.purpleAccent, Colors.deepPurple],
      [Colors.teal, Colors.greenAccent],
      [Colors.orange, Colors.deepOrangeAccent],
    ];
    final List<IconData> icons = [
      Icons.event_available,
      Icons.add_circle_outline,
      Icons.today,
      Icons.schedule,
    ];
    final int idx = _displayedQuickActions.indexOf(action);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(14.r),
        onTap: () => _handleQuickAction(action),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradients[idx % gradients.length],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: gradients[idx % gradients.length][0].withOpacity(0.18),
                blurRadius: 10.r,
                offset: Offset(0, 4.h),
              ),
            ],
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 10.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icons[idx % icons.length], color: Colors.white, size: 22.w),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    action,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(12.w),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isTyping) {
          return _buildTypingIndicator();
        }
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
  final isUser = message.isUser;
  final isAssistant = !isUser;
  final isAudioPlaying = _audioPlayingMessageId == message.id;
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser)
            CircleAvatar(
              radius: 16.r,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: ClipOval(
                child: Image.asset(
                  'assets/images/ai_avatar_small.png', // <-- Place your small avatar here
                  width: 32.w,
                  height: 32.w,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          SizedBox(width: 8.w),
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: isUser
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16.r).copyWith(
                  bottomLeft:
                      isUser ? Radius.circular(16.r) : const Radius.circular(4),
                  bottomRight:
                      isUser ? const Radius.circular(4) : Radius.circular(16.r),
                ),
                border: isAssistant
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : null,
                boxShadow: isAssistant
                  ? [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : [],
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.only(right: isAssistant ? 40.w : 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MarkdownBody(
                          data: message.content,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              fontSize: 14.sp,
                              color: isUser
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                            strong: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isAssistant)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        icon: Icon(
                          isAudioPlaying ? Icons.stop_circle : Icons.volume_up,
                          color: isAudioPlaying
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.primary,
                        ),
                        tooltip: isAudioPlaying ? 'Stop audio' : 'Play audio',
                        onPressed: () async {
                          if (isAudioPlaying) {
                            await _flutterTts.stop();
                              if (mounted) setState(() => _audioPlayingMessageId = null);
                          } else {
                            await _flutterTts.stop();
                              if (mounted) setState(() => _audioPlayingMessageId = message.id);
                            await _flutterTts.speak(message.content);
                            _flutterTts.setCompletionHandler(() {
                                if (mounted) setState(() => _audioPlayingMessageId = null);
                            });
                            _flutterTts.setCancelHandler(() {
                                if (mounted) setState(() => _audioPlayingMessageId = null);
                            });
                            _flutterTts.setErrorHandler((msg) {
                                if (mounted) setState(() => _audioPlayingMessageId = null);
                            });
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(width: 8.w),
          if (isUser)
            CircleAvatar(
              radius: 16.r,
              backgroundColor: Theme.of(context).colorScheme.secondary,
              child: Icon(Icons.person, size: 16.w, color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16.r,
            backgroundColor: Colors.transparent,
            child: ClipOval(
              child: Image.asset(
                'assets/images/ai_avatar_small.png',
                width: 32.w,
                height: 32.w,
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20.r)
                  .copyWith(bottomLeft: const Radius.circular(4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) => _buildTypingDot(index)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 1500),
      curve: Interval((0.5 / 3) * index, 1.0, curve: Curves.easeInOut),
      builder: (context, value, child) {
        return Container(
          width: 8.w,
          height: 8.w,
          margin: EdgeInsets.symmetric(horizontal: 2.w),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6.r,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.r),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.send,
              color: Theme.of(context).colorScheme.primary,
              size: 24.w,
            ),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}
