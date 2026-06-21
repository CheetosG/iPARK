// lib/screens/support/support_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/custom_app_bar.dart';

class SupportDashboard extends StatefulWidget {
  const SupportDashboard({super.key});

  @override
  State<SupportDashboard> createState() => _SupportDashboardState();
}

class _SupportDashboardState extends State<SupportDashboard> {
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: "Support Panel",
        showBackButton: true,
        role: "support",
        photoUrl: _photoUrl,
        onProfileTap: () => Navigator.pushNamed(context, '/profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Staff Operations",
              style: TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.bold, 
                color: Colors.teal
              ),
            ).animate().fadeIn(),
            const SizedBox(height: 8),
            Text(
              "Monitor system activity and assist users.",
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ).animate().fadeIn(delay: 100.ms),
            
            const SizedBox(height: 32),
            
            _buildActionCard(
              title: "Live Support Chats",
              subtitle: "Interact with users in real-time",
              icon: Icons.chat_bubble_rounded,
              color: Colors.teal,
              onTap: () => Navigator.pushNamed(context, '/admin/chat-list'),
            ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1, end: 0),
            
            const SizedBox(height: 16),
            
            _buildActionCard(
              title: "Support Inbox",
              subtitle: "Manage and resolve help tickets",
              icon: Icons.confirmation_number_rounded,
              color: Colors.teal,
              onTap: () => Navigator.pushNamed(context, '/admin/support'),
            ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1, end: 0),
            
            const SizedBox(height: 16),
            
            _buildActionCard(
              title: "User Directory",
              subtitle: "Search users and view histories",
              icon: Icons.people_alt_rounded,
              color: Colors.blueGrey,
              onTap: () => Navigator.pushNamed(context, '/admin/users'),
            ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1, end: 0),
            
            const SizedBox(height: 40),
            
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.teal.withOpacity(0.1)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.teal),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      "You are currently in Staff Mode. Some administrative features like mall management are restricted.",
                      style: TextStyle(fontSize: 12, color: Colors.teal),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 600.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title, 
    required String subtitle, 
    required IconData icon, 
    required Color color,
    required VoidCallback onTap
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12, 
                      color: Colors.grey[600]
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
