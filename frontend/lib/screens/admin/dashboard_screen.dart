import 'package:flutter/material.dart';
import '../../services/admin_api_service.dart';
import '../../services/mall_api_service.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/socket_service.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/custom_app_bar.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AdminApiService _apiService = AdminApiService();
  Map<String, dynamic> _stats = {'totalUsers': 0, 'profit': 0};
  bool _isLoading = true;
  String? _photoUrl;
  StreamSubscription? _ticketSubscription;
  StreamSubscription? _systemErrorSubscription;

  @override
  void initState() {
    super.initState();
    _fetchStats();
    _setupListeners();
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

  void _setupListeners() {
    _ticketSubscription = SocketService.ticketStream.listen((data) {
      if (!mounted) return;
      _showNotification(
        "New Ticket from ${data['userName']}",
        data['subject'],
        Icons.support_agent,
        AppTheme.primaryLight,
        () => Navigator.pushNamed(context, '/admin/support'),
      );
    });

    _systemErrorSubscription = SocketService.systemErrorStream.listen((data) {
      if (!mounted) return;
      _showNotification(
        "SYSTEM ERROR [${data['errorCode']}]",
        "${data['path']}: ${data['message']}",
        Icons.report_problem,
        Colors.redAccent,
        null, // No direct view for logs yet unless we add a screen
      );
    });
  }

  void _showNotification(String title, String message, IconData icon, Color color, VoidCallback? onTap) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(message, style: const TextStyle(fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 8),
          action: onTap != null ? SnackBarAction(
            label: "VIEW",
            textColor: Colors.white,
            onPressed: onTap,
          ) : null,
        ),
      );
  }

  @override
  void dispose() {
    _ticketSubscription?.cancel();
    _systemErrorSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _apiService.getAdminStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error in AdminDashboard _fetchStats: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        // Show error snackbar or dialog if needed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to load dashboard: ${e.toString().replaceAll('Exception: ', '')}"),
            backgroundColor: Colors.red,
            action: SnackBarAction(label: "Retry", textColor: Colors.white, onPressed: _fetchStats),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: "Admin Dashboard",
        showBackButton: true,
        role: "admin",
        photoUrl: _photoUrl,
        onProfileTap: () => Navigator.pushNamed(context, '/profile'),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchStats,
        color: AppTheme.primaryLight,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Overview",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryLight),
                    ).animate().fadeIn(),
                    const SizedBox(height: 16),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => Navigator.pushNamed(context, '/admin/users'),
                              child: _buildStatCard(
                                title: "Total Users",
                                value: _stats['totalUsers']?.toString() ?? "0",
                                icon: Icons.people,
                                color: Colors.blue,
                                isExpanded: false,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          _buildStatCard(
                            title: "Total Profit",
                            value: "${(double.tryParse(_stats['profit']?.toString() ?? '0') ?? 0).toInt()} EGP",
                            icon: Icons.attach_money,
                            color: Colors.green,
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
  
                    const SizedBox(height: 32),
                    _buildSectionHeader("Management"),
                    const SizedBox(height: 16),
                    _buildActionCard(
                      title: "Add New Mall",
                      subtitle: "Configure spots and pricing",
                      icon: Icons.add_business,
                      onTap: () => _showAddMallDialog(context),
                    ).animate().fadeIn(delay: 400.ms),
  
                    const SizedBox(height: 16),
                    _buildActionCard(
                      title: "Edit Existing Mall",
                      subtitle: "Update mall details and photos",
                      icon: Icons.edit_note,
                      onTap: () => _showEditMallSelectionDialog(context),
                    ).animate().fadeIn(delay: 450.ms),
  
  
                    const SizedBox(height: 16),
                    _buildActionCard(
                      title: "Create Promo Code",
                      subtitle: "Manage marketing campaigns",
                      icon: Icons.local_offer,
                      onTap: () => _createPromoDialog(context),
                    ).animate().fadeIn(delay: 600.ms),
  
                    const SizedBox(height: 16),
                    _buildActionCard(
                      title: "Live Chat",
                      subtitle: "Real-time support with users",
                      icon: Icons.chat_bubble_rounded,
                      onTap: () => Navigator.pushNamed(context, '/admin/chat-list'),
                    ).animate().fadeIn(delay: 650.ms),
  
                    const SizedBox(height: 16),
                    _buildActionCard(
                      title: "Support Inbox",
                      subtitle: "View and resolve user messages",
                      icon: Icons.message_rounded,
                      onTap: () => Navigator.pushNamed(context, '/admin/support'),
                    ).animate().fadeIn(delay: 700.ms),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[700]),
    );
  }

  Widget _buildStatCard({
    required String title, 
    required String value, 
    required IconData icon, 
    required Color color,
    bool isExpanded = true,
  }) {
    Widget card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    return isExpanded ? Expanded(child: card) : card;
  }

  Widget _buildActionCard({required String title, required String subtitle, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppTheme.primaryLight.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primaryLight.withOpacity(0.1),
              child: Icon(icon, color: AppTheme.primaryLight),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showAddMallDialog(BuildContext context) {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final descriptionController = TextEditingController();
    final spotsController = TextEditingController();
    final priceController = TextEditingController();
    File? selectedImage;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text("Add New Mall"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                _buildDialogField(nameController, "Mall Name", Icons.business),
                _buildDialogField(locationController, "Location/Area", Icons.location_on),
                _buildDialogField(descriptionController, "Description", Icons.description, maxLines: 3),
                _buildDialogField(spotsController, "Total Spots", Icons.garage, isNumber: true),
                _buildDialogField(priceController, "Price Per Hour (EGP)", Icons.money, isNumber: true),
                
                const SizedBox(height: 10),
                // Image Picker UI
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                    if (picked != null) {
                      setDialogState(() => selectedImage = File(picked.path));
                    }
                  },
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(selectedImage!, fit: BoxFit.cover),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                              SizedBox(height: 8),
                              Text("Select Mall Photo", style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryLight),
              onPressed: () async {
                if (nameController.text.isEmpty || spotsController.text.isEmpty) {
                  setDialogState(() => errorMessage = "Name and Spots are required");
                  return;
                }

                setDialogState(() => errorMessage = null);
                final result = await _apiService.addMall({
                  'name': nameController.text.trim(),
                  'location': locationController.text.trim().isEmpty ? 'N/A' : locationController.text.trim(),
                  'description': descriptionController.text.trim(),
                  'totalSpots': int.tryParse(spotsController.text.trim()) ?? 0,
                  'pricePerHour': double.tryParse(priceController.text.trim()) ?? 0,
                }, imageFile: selectedImage);

                if (result['success'] == true) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mall Added Successfully")));
                  _fetchStats();
                } else {
                  setDialogState(() => errorMessage = result['message'] ?? "Failed to Add Mall");
                }
              },
              child: const Text("Create Mall"),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditMallSelectionDialog(BuildContext context) async {
    final malls = await MallApiService().getMalls();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Select Mall to Edit"),
        content: malls.isEmpty 
          ? const Text("No malls found")
          : SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: malls.length,
                itemBuilder: (ctx, index) {
                  final mall = malls[index];
                  final totalSpots = mall['totalSpots']?.toString() ?? "0";
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).cardColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: AppTheme.primaryLight.withOpacity(0.2)),
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        _showEditMallDialog(context, mall);
                      },
                      borderRadius: BorderRadius.circular(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                            child: (mall['photoUrl'] != null && mall['photoUrl'] != "")
                              ? Image.network(
                                  mall['photoUrl'],
                                  height: 120,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, o, s) => Container(
                                    height: 120,
                                    color: Colors.grey[800],
                                    child: const Icon(Icons.business, color: Colors.grey),
                                  ),
                                )
                              : Container(
                                  height: 120,
                                  color: Colors.grey[800],
                                  child: const Icon(Icons.business, color: Colors.grey),
                                ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        mall['name'] ?? "Unknown",
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      Text(
                                        mall['location'] ?? "N/A",
                                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryLight.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "$totalSpots spots",
                                    style: const TextStyle(color: AppTheme.primaryLight, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
        ],
      ),
    );
  }

  void _showEditMallDialog(BuildContext context, Map<String, dynamic> mall) {
    final nameController = TextEditingController(text: mall['name']);
    final locationController = TextEditingController(text: mall['location']);
    final descriptionController = TextEditingController(text: mall['description']);
    final priceController = TextEditingController(text: mall['pricePerHour']?.toString());
    final spotsController = TextEditingController(text: mall['totalSpots']?.toString());
    File? selectedImage;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text("Edit Mall: ${mall['name']}"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                _buildDialogField(nameController, "Mall Name", Icons.business),
                _buildDialogField(locationController, "Location/Area", Icons.location_on),
                _buildDialogField(descriptionController, "Description", Icons.description, maxLines: 3),
                _buildDialogField(priceController, "Price Per Hour (EGP)", Icons.money, isNumber: true),
                _buildDialogField(spotsController, "Total Spots", Icons.grid_view, isNumber: true),

                const SizedBox(height: 10),
                // Image Picker UI
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                    if (picked != null) {
                      setDialogState(() => selectedImage = File(picked.path));
                    }
                  },
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(selectedImage!, fit: BoxFit.cover),
                          )
                        : (mall['photoUrl'] != null && mall['photoUrl'] != "")
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  mall['photoUrl'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, obj, st) => const Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                                ),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text("Change Mall Photo", style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryLight),
              onPressed: () async {
                if (nameController.text.isEmpty) {
                  setDialogState(() => errorMessage = "Name is required");
                  return;
                }

                setDialogState(() => errorMessage = null);
                final result = await _apiService.updateMall(
                  mall['_id'] ?? mall['id'],
                  {
                    'name': nameController.text.trim(),
                    'location': locationController.text.trim(),
                    'description': descriptionController.text.trim(),
                    'pricePerHour': double.tryParse(priceController.text.trim()) ?? 0,
                    'totalSpots': int.tryParse(spotsController.text.trim()) ?? 0,
                  },
                  imageFile: selectedImage,
                );

                if (result['success'] == true) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mall Updated Successfully")));
                  _fetchStats();
                } else {
                  setDialogState(() => errorMessage = result['message'] ?? "Failed to Update Mall");
                }
              },
              child: const Text("Update Mall"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogField(TextEditingController controller, String label, IconData icon, {bool isNumber = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  void _createPromoDialog(BuildContext context) {
    final codeController = TextEditingController();
    final discountController = TextEditingController();
    String? errorMessage;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text("Create Promo Code"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              _buildDialogField(codeController, "Promo Code", Icons.local_offer),
              _buildDialogField(discountController, "Discount Percentage", Icons.percent, isNumber: true),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                if (codeController.text.isEmpty || discountController.text.isEmpty) {
                  setDialogState(() => errorMessage = "All fields are required");
                  return;
                }
                setDialogState(() => errorMessage = null);
                final result = await _apiService.createPromoCode({
                  'code': codeController.text.trim(),
                  'discount': int.tryParse(discountController.text.trim()) ?? 0,
                });
                
                if (result['success'] == true) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Created Successfully")));
                } else {
                  setDialogState(() => errorMessage = "Failed to create promo code");
                }
              },
              child: const Text("Create"),
            ),
          ],
        ),
      ),
    );
  }
}
