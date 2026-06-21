import 'package:flutter/material.dart';
import '../../services/user_api_service.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/custom_app_bar.dart';
import 'support_chat_screen.dart';

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> with SingleTickerProviderStateMixin {
  final UserApiService _apiService = UserApiService();
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  late TabController _tabController;
  bool _isLoading = false;
  List<Map<String, dynamic>> _myTickets = [];
  bool _isHistoryLoading = false;
  User? _currentUser;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchUserData();
    _fetchHistory();
  }

  Future<void> _fetchUserData() async {
    try {
      final user = await _apiService.getUserProfile();
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _photoUrl = prefs.getString('photoUrl');
        });
      }
    } catch (e) {
      debugPrint('[SUPPORT ERROR] Failed to fetch user profile: $e');
      // Fallback to local SharedPreferences cache so the Live Chat button works offline
      try {
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('userId') ?? '';
        final phoneNumber = prefs.getString('phoneNumber') ?? '';
        final name = prefs.getString('name') ?? 'User';
        final email = prefs.getString('email') ?? '';
        final nationalId = prefs.getString('nationalId') ?? '';
        final carPlate = prefs.getString('carPlate') ?? '';
        final role = prefs.getString('role') ?? 'user';
        
        if (userId.isNotEmpty && mounted) {
          setState(() {
            _currentUser = User(
              id: userId,
              phoneNumber: phoneNumber,
              name: name,
              email: email,
              nationalId: nationalId,
              carPlate: carPlate,
              role: role,
              points: 0,
              isVerified: true,
              createdAt: DateTime.now(),
            );
            _photoUrl = prefs.getString('photoUrl');
          });
        }
      } catch (cacheErr) {
        debugPrint('[SUPPORT ERROR] Cache fallback failed: $cacheErr');
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _fetchHistory() async {
    try {
      setState(() => _isHistoryLoading = true);
      final tickets = await _apiService.getMySupportTickets();
      if (mounted) {
        setState(() {
          _myTickets = tickets;
          _isHistoryLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[SUPPORT ERROR] Failed to fetch tickets history: $e');
      if (mounted) {
        setState(() => _isHistoryLoading = false);
      }
    }
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final result = await _apiService.submitSupportTicket(
      _subjectController.text,
      _messageController.text,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        _subjectController.clear();
        _messageController.clear();
        _fetchHistory();
        _tabController.animateTo(1);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Message sent successfully!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? "Failed to send message")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: "Help & Support",
        showBackButton: true,
        photoUrl: _photoUrl,
        onProfileTap: () => Navigator.pushNamed(context, '/profile'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryLight,
          labelColor: AppTheme.primaryLight,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: "New Request"),
            Tab(text: "My Tickets"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNewRequestForm(),
          _buildTicketsHistory(),
        ],
      ),
    );
  }

  Widget _buildNewRequestForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "How can we help you?",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryLight),
            ).animate().fadeIn(),
            const SizedBox(height: 8),
            const Text(
              "Please describe your issue or feedback in detail.",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 24),
            
            // Live Chat Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryLight, AppTheme.primaryLight.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: AppTheme.primaryLight.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
                ],
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.support_agent, color: Colors.white, size: 40),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Need Instant Help?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                            Text("Chat with our live support team now.", style: TextStyle(color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _currentUser == null ? null : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SupportChatScreen(user: _currentUser!)),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryLight,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text("START LIVE CHAT", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 150.ms).scale(begin: const Offset(0.95, 0.95)),
            
            const SizedBox(height: 32),
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text("OR SEND A TICKET", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                Expanded(child: Divider()),
              ],
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 24),
            TextFormField(
              controller: _subjectController,
              decoration: InputDecoration(
                labelText: "Subject",
                hintText: "e.g., Payment issue, Missing points",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                prefixIcon: const Icon(Icons.subject, color: AppTheme.primaryLight),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
              validator: (v) => v!.isEmpty ? "Required" : null,
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: 20),
            TextFormField(
              controller: _messageController,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: "Write your message here...",
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
              validator: (v) => v!.isEmpty ? "Required" : null,
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitTicket,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: AppTheme.primaryLight,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 5,
              ),
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("SUBMIT REQUEST", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketsHistory() {
    if (_isHistoryLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight));
    }

    if (_myTickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text("No support history found", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchHistory,
      color: AppTheme.primaryLight,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myTickets.length,
        itemBuilder: (context, index) {
          final ticket = _myTickets[index];
          final isSolved = ticket['status'] == 'solved';
          final date = DateTime.tryParse(ticket['createdAt'] ?? '')?.toLocal();

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 2,
            child: ExpansionTile(
              leading: Icon(
                isSolved ? Icons.check_circle : Icons.pending,
                color: isSolved ? Colors.green : Colors.orange,
              ),
              title: Text(ticket['subject'] ?? "Support Request", style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(date != null ? DateFormat('MMM dd, yyyy').format(date) : ""),
              trailing: Text(
                isSolved ? "SOLVED" : "OPEN",
                style: TextStyle(
                  color: isSolved ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Your Message:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(ticket['message'] ?? ""),
                      if (isSolved && ticket['adminResponse'] != null) ...[
                        const Divider(height: 24),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.primaryLight.withOpacity(0.1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.support_agent, size: 14, color: AppTheme.primaryLight),
                                  SizedBox(width: 8),
                                  Text("Official Response:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryLight)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(ticket['adminResponse'], style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.1, end: 0);
        },
      ),
    );
  }
}
