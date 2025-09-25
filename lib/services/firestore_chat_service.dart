import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message.dart';

class FirestoreChatService {
  static final _firestore = FirebaseFirestore.instance;
  static String get _userId => FirebaseAuth.instance.currentUser?.uid ?? 'default';

  static CollectionReference get _chatCollection =>
      _firestore.collection('user_chats').doc(_userId).collection('messages');

  static Future<List<ChatMessage>> getMessages() async {
    final query = await _chatCollection.get();
    return query.docs.map((doc) => ChatMessage.fromMap(doc.data() as Map<String, dynamic>)).toList();
  }

  static Future<void> addMessage(ChatMessage message) async {
    await _chatCollection.doc(message.id).set(message.toMap());
  }

  static Future<void> deleteChat(String chatId) async {
    final query = await _chatCollection.where('chatId', isEqualTo: chatId).get();
    for (final doc in query.docs) {
      await doc.reference.delete();
    }
  }
}
