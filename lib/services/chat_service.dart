import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> sendMessage(
      String chatId,
      String senderId,
      String text, {
        String messageType = 'text',
      }) async {
    try {
      print('📤 Enviando mensaje al chat: $chatId');

      final chatRef = _firestore.collection('chats').doc(chatId);

      // Dividir el chatId para obtener participantes
      final parts = chatId.split('_');
      final p1 = parts[0];
      final p2 = parts.length > 1 ? parts[1] : 'unknown';

      print('👥 Participantes: $p1, $p2');

      // Crear/actualizar el documento del chat
      await chatRef.set({
        'participant1Id': p1,
        'participant2Id': p2,
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ Chat actualizado/creado');

      // Agregar el mensaje
      final messageData = {
        'senderId': senderId,
        'text': text,
        'messageType': messageType,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await chatRef.collection('messages').add(messageData);
      print('✅ Mensaje enviado');

    } catch (e) {
      print('❌ ERROR AL ENVIAR MENSAJE: $e');
      rethrow; // Relanzar el error para que lo vea la UI
    }
  }

  // ✅ FUNCIÓN OPTIMIZADA CON PAGINACIÓN
  Stream<List<MessageModel>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(50) // 🚀 AQUÍ ESTÁ LA OPTIMIZACIÓN: Solo descarga los últimos 50 mensajes
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return MessageModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }
}