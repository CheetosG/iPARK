import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../services/admin_api_service.dart';
import '../../services/base_api_service.dart';
import '../../theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/custom_app_bar.dart';

class UserDetailScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const UserDetailScreen({super.key, required this.user});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  final AdminApiService _apiService = AdminApiService();
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;
  bool _isActionLoading = false;
  late bool _isCurrentlyBanned;
  late String _currentRole;
  String? _photoUrl;
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _isCurrentlyBanned = widget.user['isBanned'] == true;
    _currentRole = widget.user['role'] ?? 'user';
    _fetchUserDetails();
    _fetchHistory();
    _loadProfile();
  }

  Future<void> _fetchUserDetails() async {
    final freshUser = await _apiService.getUser(widget.user['_id'] ?? widget.user['id']);
    if (freshUser.isNotEmpty && mounted) {
      setState(() {
        _isCurrentlyBanned = freshUser['isBanned'] == true;
        _currentRole = freshUser['role'] ?? 'user';
        // We can update other fields if needed
      });
    }
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _photoUrl = prefs.getString('photoUrl');
        _currentUserRole = prefs.getString('role');
      });
    }
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    final history = await _apiService.getUserReservations(widget.user['_id'] ?? widget.user['id']);
    if (mounted) {
      setState(() {
        _history = history;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: "User Details",
        showBackButton: true,
        photoUrl: _photoUrl,
        onProfileTap: () => Navigator.pushNamed(context, '/profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildProfileCard(),
            const SizedBox(height: 20),
            _buildModerationActions(),
            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.history, color: AppTheme.primaryLight),
                const SizedBox(width: 10),
                Text(
                  "Reservation History",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ).animate().fadeIn(),
            const SizedBox(height: 20),
            _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
                : _history.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _history.length,
                        itemBuilder: (context, index) => _buildHistoryItem(_history[index], index),
                      ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryLight.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: _isCurrentlyBanned ? Colors.grey : AppTheme.primaryLight,
            backgroundImage: widget.user['photoUrl'] != null && widget.user['photoUrl'].toString().isNotEmpty
                ? NetworkImage("${BaseApiService.baseUrl.replaceAll('/api', '')}/${widget.user['photoUrl']}")
                : null,
            child: widget.user['photoUrl'] == null || widget.user['photoUrl'].toString().isEmpty
                ? Text(
                    (widget.user['name'] ?? "U")[0].toUpperCase(),
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                  )
                : null,
          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.user['name'] ?? "User",
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              if (_currentRole != 'user') ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(10)),
                  child: Text(_currentRole.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
              if (_isCurrentlyBanned) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                  child: const Text("BANNED", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.phone, widget.user['phoneNumber'] ?? "No Phone"),
          _buildInfoRow(Icons.email, widget.user['email'] ?? "No Email"),
          _buildInfoRow(Icons.credit_card, "National ID: ${widget.user['nationalId'] ?? 'N/A'}"),
          _buildInfoRow(Icons.directions_car, "Plate: ${widget.user['carPlate'] ?? 'N/A'}"),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(15)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Text(
                  "Points Balance: ${widget.user['points'] ?? 0}",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Text(text, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildModerationActions() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05), 
            blurRadius: 15, 
            offset: const Offset(0, 5)
          ),
        ],
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1), 
                  borderRadius: BorderRadius.circular(8)
                ),
                child: const Icon(Icons.security, color: Colors.red, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                "Moderation Actions", 
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 16,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                )
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (!(_currentUserRole == 'support' && (_currentRole == 'admin' || _currentRole == 'support')))
                Expanded(
                  child: _buildModerationButton(
                    onPressed: _isActionLoading ? null : _toggleBan,
                    icon: _isCurrentlyBanned ? Icons.check_circle : Icons.block,
                    label: _isCurrentlyBanned ? "UNBAN" : "BAN USER",
                    color: _isCurrentlyBanned ? Colors.green : Colors.red,
                  ),
                ),
              if (_currentUserRole == 'admin') ...[
                const SizedBox(width: 12),
                if (_currentRole == 'user')
                  Expanded(
                    child: _buildModerationButton(
                      onPressed: _isActionLoading ? null : _promoteToSupport,
                      icon: Icons.support_agent,
                      label: "PROMOTE",
                      color: AppTheme.primaryLight,
                    ),
                  )
                else if (_currentRole == 'support')
                  Expanded(
                    child: _buildModerationButton(
                      onPressed: _isActionLoading ? null : _demoteToUser,
                      icon: Icons.person_remove,
                      label: "DEMOTE",
                      color: Colors.grey[700]!,
                    ),
                  ),
              ],
              if (_currentUserRole == 'support' && _currentRole == 'user')
                const Expanded(child: SizedBox()), // Placeholder for layout balance if needed
            ],
          ),
          if (_isActionLoading)
            const Padding(
              padding: EdgeInsets.only(top: 12.0),
              child: LinearProgressIndicator(minHeight: 2, backgroundColor: Colors.transparent),
            ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildModerationButton({required VoidCallback? onPressed, required IconData icon, required String label, required Color color}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Future<void> _toggleBan() async {
    setState(() => _isActionLoading = true);
    final result = await _apiService.toggleBanStatus(widget.user['_id'] ?? widget.user['id']);
    if (mounted) {
      setState(() {
        _isActionLoading = false;
        if (result['success'] == true) {
          _isCurrentlyBanned = result['isBanned'];
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_isCurrentlyBanned ? "User banned successfully" : "User unbanned successfully")),
          );
        }
      });
    }
  }

  Future<void> _promoteToSupport() async {
    _updateRole('support');
  }

  Future<void> _demoteToUser() async {
    _updateRole('user');
  }

  Future<void> _updateRole(String role) async {
    setState(() => _isActionLoading = true);
    final result = await _apiService.updateUserRole(widget.user['_id'] ?? widget.user['id'], role);
    if (mounted) {
      setState(() {
        _isActionLoading = false;
        if (result['success'] == true) {
          _currentRole = result['role'];
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Role updated to $_currentRole")),
          );
        }
      });
    }
  }

  Widget _buildHistoryItem(Map<String, dynamic> item, int index) {
    final mall = item['mallId']?['name'] ?? "Unknown Mall";
    final spot = item['spotId']?['spotNumber'] ?? "N/A";
    final date = DateTime.tryParse(item['startTime'] ?? '')?.toLocal();
    final status = (item['status'] ?? 'pending').toString().toUpperCase();
    final amount = double.tryParse(item['amount']?.toString() ?? '0') ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        title: Text(mall, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Spot: $spot • Plate: ${item['carPlate'] ?? 'N/A'}"),
            if (date != null) Text(DateFormat('MMM dd, yyyy • HH:mm').format(date)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text("${amount.toStringAsFixed(1)} EGP", style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryLight)),
            Text(status, style: TextStyle(
              fontSize: 10, 
              fontWeight: FontWeight.bold, 
              color: status == 'COMPLETED' ? Colors.green : (status == 'CANCELLED' ? Colors.red : Colors.blue)
            )),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (index * 50).ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          Icon(Icons.history_toggle_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text("No reservations found for this user", style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }
}
