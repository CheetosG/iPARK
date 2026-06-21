import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/admin_api_service.dart';
import '../../services/base_api_service.dart';
import '../../theme/app_theme.dart';
import 'user_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/custom_app_bar.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final AdminApiService _apiService = AdminApiService();
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _photoUrl;
  String? _currentUserRole;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchController.addListener(_onSearchChanged);
    _loadProfile();
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final users = await _apiService.getAllUsers();
      if (mounted) {
        setState(() {
          _users = users;
          // Filter out admins if the current user is a supporter
          if (_currentUserRole == 'support') {
            _filteredUsers = users.where((u) => u['role'] != 'admin').toList();
          } else {
            _filteredUsers = users;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _users.where((user) {
        // Initial Role Filter
        if (_currentUserRole == 'support' && user['role'] == 'admin') return false;

        final name = (user['name'] ?? '').toLowerCase();
        final phone = (user['phoneNumber'] ?? '').toLowerCase();
        return name.contains(query) || phone.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: "Users Management",
        showBackButton: true,
        photoUrl: _photoUrl,
        onProfileTap: () => Navigator.pushNamed(context, '/profile'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).brightness == Brightness.light 
                      ? Colors.black.withOpacity(0.05) 
                      : Colors.black.withOpacity(0.2), 
                    blurRadius: 15, 
                    offset: const Offset(0, 5)
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  hintText: "Search name, phone, or ID...",
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryLight, size: 24),
                  suffixIcon: _searchController.text.isNotEmpty 
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 20, color: Colors.grey[400]), 
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged();
                        }
                      )
                    : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(50),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(50),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(50),
                    borderSide: const BorderSide(color: AppTheme.primaryLight, width: 1.5),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
                : _errorMessage != null
                    ? _buildErrorState()
                    : _filteredUsers.isEmpty
                        ? const Center(child: Text("No users found"))
                        : ListView.builder(
                            itemCount: _filteredUsers.length,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primaryLight.withOpacity(0.1),
                                backgroundImage: user['photoUrl'] != null && user['photoUrl'].toString().isNotEmpty
                                    ? NetworkImage("${BaseApiService.baseUrl.replaceAll('/api', '')}/${user['photoUrl']}")
                                    : null,
                                child: user['photoUrl'] == null || user['photoUrl'].toString().isEmpty
                                    ? Text(
                                        (user['name'] ?? "U")[0].toUpperCase(),
                                        style: const TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.bold),
                                      )
                                    : null,
                              ),
                              title: Row(
                                children: [
                                  Expanded(child: Text(user['name'] ?? "User", style: const TextStyle(fontWeight: FontWeight.bold))),
                                  if (user['role'] == 'admin')
                                    _buildRoleBadge("ADMIN", AppTheme.primaryLight),
                                  if (user['role'] == 'support')
                                    _buildRoleBadge("SUPPORT", Colors.teal),
                                  if (user['isBanned'] == true)
                                    _buildRoleBadge("BANNED", Colors.red),
                                ],
                              ),
                              subtitle: Text(user['phoneNumber'] ?? "No Phone"),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.stars, color: Colors.amber, size: 16),
                                  Text("${user['points'] ?? 0}"),
                                ],
                              ),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UserDetailScreen(user: user),
                                  ),
                                );
                                if (mounted) _fetchUsers();
                              },
                            ),
                          ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.1, end: 0);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 10),
          Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _fetchUsers,
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryLight),
            child: const Text("Retry Connection", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
