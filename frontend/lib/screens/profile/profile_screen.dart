import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/user_api_service.dart';
import '../../services/base_api_service.dart';
import '../../models/user_model.dart';
import 'package:provider/provider.dart';
import '../../providers/reservation_provider.dart';
import '../../widgets/custom_app_bar.dart';

class ProfileScreen extends StatefulWidget {
  final bool showBackButton;
  const ProfileScreen({super.key, this.showBackButton = false});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserApiService _apiService = UserApiService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nationalIdController = TextEditingController();
  final TextEditingController _carPlateController = TextEditingController();
  bool _isLoading = false;
  bool _isEditing = false;
  Map<String, dynamic> _user = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      
      try {
        final User freshUser = await _apiService.getUserProfile();
        if (freshUser.id.isNotEmpty) {
          await prefs.setString('name', freshUser.name);
          await prefs.setString('email', freshUser.email);
          await prefs.setString('nationalId', freshUser.nationalId);
          await prefs.setString('carPlate', freshUser.carPlate);
          await prefs.setString('role', freshUser.role);
          if (freshUser.photoUrl != null) {
            await prefs.setString('photoUrl', freshUser.photoUrl!);
          }
          
          // Sync with Provider to avoid stale role in UI
          if (mounted) {
            Provider.of<ReservationProvider>(context, listen: false).setUserRole(freshUser.role);
          }
        }
      } catch (apiError) {
        print('API Load failed, using local cache: $apiError');
      }

      final phoneNumber = prefs.getString('phoneNumber') ?? '';
      final name = prefs.getString('name') ?? '';
      final email = prefs.getString('email') ?? '';
      final nationalId = prefs.getString('nationalId') ?? '';
      final carPlate = prefs.getString('carPlate') ?? '';
      final photoUrl = prefs.getString('photoUrl') ?? '';

      if (!mounted) return;
      setState(() {
        _user = {
          'phoneNumber': phoneNumber,
          'name': name,
          'email': email,
          'nationalId': nationalId,
          'carPlate': carPlate,
          'photoUrl': photoUrl,
        };
        _nameController.text = name;
        _emailController.text = email;
        _nationalIdController.text = nationalId;
        _carPlateController.text = carPlate;
      });
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.isEmpty || 
        _emailController.text.isEmpty || 
        _nationalIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all required fields")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = await _apiService.updateUserProfile({
        'name': _nameController.text,
        'email': _emailController.text,
        'nationalId': _nationalIdController.text,
        'carPlate': _carPlateController.text,
      });

      if (data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('name', _nameController.text);
        await prefs.setString('email', _emailController.text);
        await prefs.setString('nationalId', _nationalIdController.text);
        await prefs.setString('carPlate', _carPlateController.text);

        if (!mounted) return;
        setState(() {
          _user = {
            'phoneNumber': _user['phoneNumber'],
            'name': _nameController.text,
            'email': _emailController.text,
            'nationalId': _nationalIdController.text,
            'carPlate': _carPlateController.text,
            'photoUrl': _user['photoUrl'],
          };
          _isEditing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully!")),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Update failed')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      
      if (image != null) {
        // Crop Image logic
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: image.path,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Resize Photo',
              toolbarColor: AppTheme.primaryLight,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: false,
              activeControlsWidgetColor: AppTheme.primaryLight,
              aspectRatioPresets: [
                CropAspectRatioPreset.square,
                CropAspectRatioPreset.ratio3x2,
                CropAspectRatioPreset.original,
                CropAspectRatioPreset.ratio4x3,
                CropAspectRatioPreset.ratio16x9
              ],
            ),
            IOSUiSettings(
              title: 'Resize Photo',
              aspectRatioPresets: [
                CropAspectRatioPreset.square,
                CropAspectRatioPreset.ratio3x2,
                CropAspectRatioPreset.original,
                CropAspectRatioPreset.ratio4x3,
                CropAspectRatioPreset.ratio16x9
              ],
            ),
          ],
        );

        if (croppedFile != null) {
          if (!mounted) return;
          setState(() => _isLoading = true);
          final response = await _apiService.uploadProfilePhoto(File(croppedFile.path));
          
          if (response['success'] == true) {
            final newPhotoUrl = response['photoUrl'];
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('photoUrl', newPhotoUrl);
            
            if (!mounted) return;
            setState(() {
              _user['photoUrl'] = newPhotoUrl;
              _isLoading = false;
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Profile photo updated successfully!")),
            );
          } else {
            throw Exception(response['message'] ?? "Upload failed");
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString().replaceAll('Exception: ', '')}")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userRole = Provider.of<ReservationProvider>(context, listen: false).userRole;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      appBar: CustomAppBar(
        title: "My Profile",
        showBackButton: widget.showBackButton,
        showProfile: false, // We are already here
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.check, color: AppTheme.primaryLight, size: 28),
              onPressed: _saveProfile,
            )
          else
            IconButton(
              icon: const Icon(Icons.edit, color: AppTheme.primaryLight),
              onPressed: _toggleEdit,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
          : RefreshIndicator(
              onRefresh: _loadUserData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 110),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: AppTheme.primaryLight,
                          backgroundImage: _user['photoUrl'] != null && _user['photoUrl'].isNotEmpty
                              ? NetworkImage("${BaseApiService.baseUrl.split('/api')[0]}/${_user['photoUrl']}")
                              : null,
                          child: _user['photoUrl'] == null || _user['photoUrl'].isEmpty
                              ? const Icon(Icons.person, size: 60, color: Colors.white)
                              : null,
                        ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryLight,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _user['name'] ?? "User",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: (userRole == 'admin' ? Colors.amber : (userRole == 'support' ? Colors.blue : AppTheme.primaryLight)).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (userRole == 'admin' ? Colors.amber : (userRole == 'support' ? Colors.blue : AppTheme.primaryLight)).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_user, 
                          size: 14, 
                          color: userRole == 'admin' ? Colors.amber : (userRole == 'support' ? Colors.blue : AppTheme.primaryLight),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "${userRole.toUpperCase()} MEMBER",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: userRole == 'admin' ? Colors.amber : (userRole == 'support' ? Colors.blue : AppTheme.primaryLight),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildProfileCard(
                    icon: Icons.phone,
                    label: "Phone Number",
                    value: _user['phoneNumber'] ?? "N/A",
                  ),
                  const SizedBox(height: 16),
                  _buildProfileCard(
                    icon: Icons.person,
                    label: "Full Name",
                    value: _isEditing ? _nameController.text : _user['name'] ?? "N/A",
                    isEditable: _isEditing,
                    controller: _nameController,
                  ),
                  const SizedBox(height: 16),
                  _buildProfileCard(
                    icon: Icons.email,
                    label: "Email Address",
                    value: _isEditing ? _emailController.text : _user['email'] ?? "N/A",
                    isEditable: _isEditing,
                    controller: _emailController,
                  ),
                  const SizedBox(height: 16),
                  _buildProfileCard(
                    icon: Icons.sd_card,
                    label: "National ID",
                    value: _isEditing ? _nationalIdController.text : _user['nationalId'] ?? "N/A",
                    isEditable: _isEditing,
                    controller: _nationalIdController,
                  ),
                  const SizedBox(height: 16),
                  _buildProfileCard(
                    icon: Icons.directions_car,
                    label: "Car Plate",
                    value: _isEditing ? _carPlateController.text : _user['carPlate'] ?? "N/A",
                    isEditable: _isEditing,
                    controller: _carPlateController,
                  ),
                  const SizedBox(height: 16),
                  if (!_isEditing) ...[
                    _buildSpecialActionCard(
                      icon: Icons.support_agent,
                      label: "Help & Support",
                      value: "Chat with our team now",
                      onTap: () => Navigator.pushNamed(context, '/contact-support'),
                    ),
                    const SizedBox(height: 30),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.clear();
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text("Logout"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          )
    );
  }

  Widget _buildProfileCard({
    required IconData icon,
    required String label,
    required String value,
    bool isEditable = false,
    TextEditingController? controller,
    VoidCallback? onTap,
    Color? iconColor,
  }) {
    final Color effectiveIconColor = iconColor ?? AppTheme.primaryLight;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppTheme.primaryLight.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: effectiveIconColor.withOpacity(0.1),
          child: Icon(icon, color: effectiveIconColor),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        subtitle: isEditable
            ? TextField(
                controller: controller,
                decoration: const InputDecoration(border: InputBorder.none),
              )
            : Text(
                value,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
      ),
    );
  }

  Widget _buildSpecialActionCard({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryLight, Color(0xFF0077B6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
          subtitle: Text(value, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
          trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
        ),
      ),
    );
  }
}