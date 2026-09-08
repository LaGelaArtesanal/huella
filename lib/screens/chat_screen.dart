import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/message_model.dart';
import '../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String currentUserId;
  final String otherUserId;
  final bool isWalker;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.currentUserId,
    required this.otherUserId,
    this.isWalker = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _chatService = ChatService();
  final _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  // ✅ CAMBIO: Usamos el ID del último mensaje para detectar nuevos,
  // en lugar del length, para que funcione perfecto con la paginación (.limit)
  String? _lastSeenMessageId;

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    // Inicialización rápida del plugin de notificaciones locales
    _localNotifications.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));
  }

  void _sendMessage() async {
    if (_textController.text.trim().isEmpty || _isSending) return;
    setState(() => _isSending = true);

    try {
      await _chatService.sendMessage(
        widget.chatId,
        widget.currentUserId,
        _textController.text.trim(),
      );
      _textController.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al enviar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _sendQuickAction(String actionText, String type) async {
    if (_isSending) return;
    setState(() => _isSending = true);

    try {
      await _chatService.sendMessage(
        widget.chatId,
        widget.currentUserId,
        actionText,
        messageType: type,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al enviar acción: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0, // reverse: true, así que 0 es el final (abajo)
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ✅ Función para mostrar notificación local con sonido
  Future<void> _showChatNotification(String title, String text) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'chat_message_channel',
      'Mensajes de Chat Huella',
      channelDescription: 'Notificaciones con sonido para nuevos mensajes de chat',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      text,
      platformChannelSpecifics,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(widget.otherUserId).get(),
          builder: (context, snapshot) {
            String displayName = 'Cargando...';
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              displayName = data?['name'] ?? 'Usuario';
            }
            return Text(displayName, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold));
          },
        ),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _chatService.getMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;

                // ✅ DETECTAR MENSAJE NUEVO DEL OTRO USUARIO (Lógica mejorada para paginación)
                if (messages.isNotEmpty) {
                  final latestMsg = messages[0]; // reverse: true, el índice 0 es el más nuevo

                  // Si ya hemos visto mensajes, y el más nuevo tiene un ID diferente,
                  // y NO lo enviamos nosotros, entonces es un mensaje nuevo entrante.
                  if (_lastSeenMessageId != null &&
                      latestMsg.id != _lastSeenMessageId &&
                      latestMsg.senderId != widget.currentUserId) {

                    _showChatNotification('Nuevo mensaje', latestMsg.text);
                  }

                  // Actualizamos el último ID visto
                  _lastSeenMessageId = latestMsg.id;
                }

                if (messages.isEmpty) {
                  return Center(child: Text('Inicia la conversación...', style: TextStyle(color: Colors.grey[400])));
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == widget.currentUserId;
                    final isAction = msg.messageType != 'text';

                    String timeString = '--:--';
                    if (msg.timestamp != null) {
                      timeString = '${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}';
                    }

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.orange : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              msg.text,
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black87,
                                fontWeight: isAction ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              timeString,
                              style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          if (widget.isWalker) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _QuickActionButton(label: '✅ Confirmar Paseo', onTap: () => _sendQuickAction('He confirmado el paseo. ¡Nos vemos pronto!', 'action_confirm')),
                  const SizedBox(width: 8),
                  _QuickActionButton(label: '📍 Llegué al punto', onTap: () => _sendQuickAction('Ya llegué al punto de encuentro.', 'action_arrived')),
                ],
              ),
            ),
          ] else ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _QuickActionButton(label: '🐶 Mi perro está listo', onTap: () => _sendQuickAction('Mi perrito ya está listo para salir.', 'action_ready')),
                ],
              ),
            ),
          ],

          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, -2))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    enabled: !_isSending,
                    decoration: InputDecoration(
                      hintText: _isSending ? 'Enviando...' : 'Escribe un mensaje...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: _isSending ? Colors.grey : Colors.orange,
                  child: _isSending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade50,
        foregroundColor: Colors.blue.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}