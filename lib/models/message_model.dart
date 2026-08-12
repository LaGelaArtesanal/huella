import 'package:cloud_firestore/cloud_firestore.dart'; // <--- IMPORTANTE: Agregar esto

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final DateTime timestamp; // Ahora siempre será DateTime
  final bool isRead;
  final String messageType;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.isRead = false,
    this.messageType = 'text',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp, // Firestore acepta DateTime directamente
      'isRead': isRead,
      'messageType': messageType,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map, String docId) {
    // CORRECCIÓN: Manejar tanto Timestamp de Firebase como String
    DateTime msgTime;
    if (map['timestamp'] is Timestamp) {
      msgTime = (map['timestamp'] as Timestamp).toDate();
    } else if (map['timestamp'] is String) {
      msgTime = DateTime.parse(map['timestamp']);
    } else {
      msgTime = DateTime.now(); // Fallback por seguridad
    }

    return MessageModel(
      id: docId,
      chatId: map['chatId'] ?? '',
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      timestamp: msgTime,
      isRead: map['isRead'] ?? false,
      messageType: map['messageType'] ?? 'text',
    );
  }
}