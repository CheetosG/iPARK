import 'package:flutter/material.dart';
import '../../services/admin_api_service.dart';
import '../../services/base_api_service.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/custom_app_bar.dart';

class AdminChatListScreen extends StatefulWidget {
  const AdminChatListScreen({super.key});

  @override
  State<AdminChatListScreen> createState() => _AdminChatListScreenState();
}

class _AdminChatListScreenState extends State<AdminChatListScreen> {
  final AdminApiService _apiService = AdminApiService();
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _fetchConversations();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _photoUrl = prefs.getString('photoUrl');
      });
    }
  }

  Future<void> _fetchConversations() async {
    setState(() => _isLoading = true);
    final conversations = await _apiService.getChatConversations();
    if (mounted) {
      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: "Support Conversations",
        showBackButton: true,
        photoUrl: _photoUrl,
        onProfileTap: () => Navigator.pushNamed(context, '/profile'),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchConversations,
        color: AppTheme.primaryLight,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
            : _conversations.isEmpty
                ? ListView( // Wrap empty state in ListView for RefreshIndicator to work
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                      _buildEmptyState(),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _conversations.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 70),
                    itemBuilder: (context, index) {
                      final convo = _conversations[index];
                      final userDetails = convo['userDetails'] ?? {};
                      final lastMsg = convo['lastMessage'] ?? "";
                      final lastSender = convo['lastSenderName'] ?? "User";
                      final time = DateTime.tryParse(convo['lastCreatedAt'] ?? '')?.toLocal();

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryLight.withOpacity(0.1),
                          backgroundImage: userDetails['photoUrl'] != null && userDetails['photoUrl'].toString().isNotEmpty
                              ? NetworkImage("${BaseApiService.baseUrl.replaceAll('/api', '')}/${userDetails['photoUrl']}")
                              : null,
                          child: userDetails['photoUrl'] == null || userDetails['photoUrl'].toString().isEmpty
                              ? Text(
                                  (userDetails['name'] ?? "U")[0].toUpperCase(),
                                  style: const TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        title: Text(
                          userDetails['name'] ?? "Unknown User",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "$lastSender: $lastMsg",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            fontSize: 13,
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (time != null)
                              Text(
                                DateFormat('HH:mm').format(time),
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                          ],
                        ),
                        onTap: () {
                          Navigator.pushNamed(
                            context, 
                            '/admin/chat', 
                            arguments: {
                              'userId': convo['_id'],
                              'userName': userDetails['name'] ?? "User",
                              'user': userDetails,
                            }
                          );
                        },
                      ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.1, end: 0);
                    },
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No support conversations yet",
            style: TextStyle(
              color: Theme.of(context).textTheme.titleMedium?.color,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "When users start a live chat, they will appear here.",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
