import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../services/user_api_service.dart';
import '../../services/base_api_service.dart';
import '../../theme/app_theme.dart';
import '../../models/user_model.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/custom_app_bar.dart';

class SupportChatScreen extends StatefulWidget {
  final User user;
  const SupportChatScreen({super.key, required this.user});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final UserApiService _apiService = UserApiService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late IO.Socket socket;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    _initSocket();
  }


  void _initSocket() {
    socket = IO.io(BaseApiService.baseUrl.replaceFirst('/api', ''), <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      print('Connected to socket');
      socket.emit('join_chat', {
        'userId': widget.user.id,
        'userName': widget.user.name,
      });
    });

    socket.on('receive_chat_message', (data) {
      if (mounted) {
        final incoming = Map<String, dynamic>.from(data);
        
        // Deduplication: Check if this message (by sender, content, or the new clientMsgId) 
        // already exists in the list (sent via optimistic update).
        bool alreadyExists = _messages.any((m) => 
          m['_id'] == incoming['_id'] || 
          (incoming['clientMsgId'] != null && m['clientMsgId'] == incoming['clientMsgId']) ||
          (m['senderId'].toString() == incoming['senderId'].toString() &&
           m['message'] == incoming['message'] &&
           m['_id'] == null) // fallback to identify optimistic message
        );

        if (!alreadyExists) {
          setState(() {
            _messages.add(incoming);
          });
          _scrollToBottom();
        } else {
          // Update the locally-sent optimistic message with final DB data (like _id)
          setState(() {
            final index = _messages.indexWhere((m) => 
              (incoming['clientMsgId'] != null && m['clientMsgId'] == incoming['clientMsgId']) ||
              (m['senderId'].toString() == incoming['senderId'].toString() &&
               m['message'] == incoming['message'] &&
               m['_id'] == null)
            );
            if (index != -1) {
              _messages[index] = incoming;
            }
          });
        }
      }
    });

    socket.onDisconnect((_) => print('Disconnected from socket'));
  }

  Future<void> _fetchHistory() async {
    try {
      final history = await _apiService.getChatHistory();
      if (mounted) {
        setState(() {
          _messages = history;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('[SUPPORT CHAT ERROR] Failed to fetch chat history: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    
    if (!socket.connected) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text("Connecting to support... please wait."), backgroundColor: Colors.orange)
       );
       socket.connect();
       return;
    }

    final clientMsgId = "c_${DateTime.now().millisecondsSinceEpoch}_${widget.user.id}";

    final messageData = {
      'userId': widget.user.id,
      'senderId': widget.user.id,
      'senderName': widget.user.name,
      'message': _messageController.text.trim(),
      'isAdmin': false,
      'createdAt': DateTime.now().toIso8601String(),
      'clientMsgId': clientMsgId,
    };

    // Optimistic Update
    setState(() {
      _messages.add(messageData);
    });
    _scrollToBottom();

    socket.emit('send_chat_message', messageData);
    _messageController.clear();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    socket.disconnect();
    socket.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(
        title: "iPark Live Support",
        showBackButton: true,
        showLogo: true,
        showProfile: false,
        onProfileTap: () => Navigator.pushNamed(context, '/profile'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: const Center(
              child: Text(
                "Online • Ready to help", 
                style: TextStyle(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.bold)
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
                : _messages.isEmpty
                    ? const Center(child: Text("Start a conversation with our support team."))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg['senderId'].toString() == widget.user.id.toString();
                          final time = DateTime.tryParse(msg['createdAt'] ?? '')?.toLocal();

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLight,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(15),
                                  topRight: const Radius.circular(15),
                                  bottomLeft: Radius.circular(isMe ? 15 : 0),
                                  bottomRight: Radius.circular(isMe ? 0 : 15),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  if (!isMe)
                                    Text(
                                      msg['senderName'] ?? "Support",
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    msg['message'] ?? "",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    time != null ? DateFormat('HH:mm').format(time) : "",
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
                        },
                      ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: AppTheme.primaryLight.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: "Type your message...",
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 5, vertical: 12),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sendMessage,
            icon: const Icon(Icons.send, color: AppTheme.primaryLight, size: 24),
          ),
        ],
      ),
    );
  }
}
