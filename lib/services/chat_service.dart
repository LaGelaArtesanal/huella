import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Generar ID único ordenado alfabéticamente
  String getChatId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2];
    ids.sort();
    return '${ids[0]}_${ids[1]}';
  }

  // Enviar mensaje
  Future<void> sendMessage(String chatId, String senderId, String text, {String messageType = 'text'}) async {
    await _firestore.collection('chats').doc(chatId).collection('messages').add({
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'messageType': messageType,
    });

    // Actualizar metadata del chat
    await _firestore.collection('chats').doc(chatId).set({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'participants': FieldValue.arrayUnion([senderId]),
    }, SetOptions(merge: true));
  }

  // Obtener stream de mensajes
  Stream<List<MessageModel>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
      return MessageModel.fromMap(doc.data(), doc.id);
    }).toList());
  }
}