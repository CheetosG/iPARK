import 'package:flutter/material.dart';
import '../../services/admin_api_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/custom_app_bar.dart';

class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  final AdminApiService _apiService = AdminApiService();
  List<Map<String, dynamic>> _tickets = [];
  bool _isLoading = true;
  String? _photoUrl;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchTickets();
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

  Future<void> _fetchTickets() async {
    setState(() => _isLoading = true);
    final tickets = await _apiService.getSupportTickets();
    if (mounted) {
      setState(() {
        _tickets = tickets;
        for (var ticket in tickets) {
          final id = ticket['_id'] ?? '';
          if (!_controllers.containsKey(id)) {
            _controllers[id] = TextEditingController();
          }
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _resolveTicket(String id, String response) async {
    if (response.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please write a response first")),
      );
      return;
    }
    final result = await _apiService.resolveTicket(id, response);
    if (result['success'] == true) {
      _fetchTickets();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: "Support Inbox",
        showBackButton: true,
        photoUrl: _photoUrl,
        onProfileTap: () => Navigator.pushNamed(context, '/profile'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
          : _tickets.isEmpty
              ? const Center(child: Text("All caught up! No active tickets."))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _tickets.length,
                  itemBuilder: (context, index) {
                    final ticket = _tickets[index];
                    final user = ticket['userId'] ?? {};
                    final isSolved = ticket['status'] == 'solved';
                    final date = DateTime.tryParse(ticket['createdAt'] ?? '')?.toLocal();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  ticket['subject'] ?? "No Subject",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isSolved ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isSolved ? "SOLVED" : "OPEN",
                                    style: TextStyle(
                                      color: isSolved ? Colors.green : Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              ticket['message'] ?? "",
                              style: TextStyle(
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8),
                              ),
                            ),
                            if (isSolved && ticket['adminResponse'] != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness == Brightness.light ? Colors.grey[100] : Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Theme.of(context).dividerColor),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Staff Response:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
                                    const SizedBox(height: 4),
                                    Text(ticket['adminResponse'], style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
                                  ],
                                ),
                              ),
                            ],
                            if (!isSolved) ...[
                              const SizedBox(height: 16),
                              TextField(
                                controller: _controllers[ticket['_id']],
                                maxLines: 2,
                                decoration: InputDecoration(
                                  hintText: "Type your response...",
                                  hintStyle: const TextStyle(fontSize: 13),
                                  fillColor: Theme.of(context).brightness == Brightness.light ? Colors.grey[50] : Colors.white.withOpacity(0.03),
                                  filled: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Theme.of(context).dividerColor),
                                  ),
                                ),
                              ),
                            ],
                            const Divider(height: 32),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "From: ${user['name'] ?? 'Unknown'}",
                                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                                    ),
                                    Text(
                                      user['phoneNumber'] ?? "",
                                      style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12),
                                    ),
                                    if (date != null)
                                      Text(
                                        DateFormat('MMM dd, HH:mm').format(date),
                                        style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6), fontSize: 11),
                                      ),
                                  ],
                                ),
                                if (!isSolved)
                                  ElevatedButton(
                                    onPressed: () => _resolveTicket(ticket['_id'], _controllers[ticket['_id']]?.text ?? ''),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                    ),
                                    child: const Text("RESPOND & SOLVE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
