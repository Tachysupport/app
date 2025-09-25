import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreSettingsService {
  static final _firestore = FirebaseFirestore.instance;

  static String get _userId => FirebaseAuth.instance.currentUser?.uid ?? 'default';

  static Future<Map<String, dynamic>> getSettings() async {
    final doc = await _firestore.collection('user_settings').doc(_userId).get();
    return doc.data() ?? {};
  }

  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    await _firestore.collection('user_settings').doc(_userId).set(settings);
  }

  static Future<void> updateSetting(String key, dynamic value) async {
    await _firestore.collection('user_settings').doc(_userId).set({key: value}, SetOptions(merge: true));
  }
}
