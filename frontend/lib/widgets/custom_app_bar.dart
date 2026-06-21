// lib/widgets/custom_app_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/base_api_service.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showProfile;
  final bool showSupportMessage;
  final bool showAdminButton;
  final bool showBackButton;
  final String? photoUrl;
  final VoidCallback? onProfileTap;
  final VoidCallback? onSupportTap;
  final VoidCallback? onAdminTap;
  final VoidCallback? onThemeToggle;
  final String? role;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool showThemeToggle;
  final bool showLogo;
  final Widget? leadingPhoto;
  final Color? backgroundColor;

  const CustomAppBar({super.key, 
    required this.title,
    this.showProfile = true,
    this.showSupportMessage = false,
    this.showAdminButton = false,
    this.showBackButton = true,
    this.photoUrl,
    this.onProfileTap,
    this.onSupportTap,
    this.onAdminTap,
    this.onThemeToggle,
    this.role,
    this.actions,
    this.bottom,
    this.showThemeToggle = false,
    this.showLogo = true,
    this.leadingPhoto,
    this.backgroundColor,
  });

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: showBackButton,
      backgroundColor: backgroundColor,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
      elevation: 0,
      bottom: bottom,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingPhoto != null) ...[
            leadingPhoto!,
            const SizedBox(width: 10),
          ],
          if (showLogo && leadingPhoto == null) ...[
            const Icon(Icons.local_parking, color: AppTheme.primaryLight),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Text(
              title, 
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryLight),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (role != null && role != 'user') ...[
            const SizedBox(width: 10),
            _buildRoleBadge(role!),
          ],
        ],
      ),
      actions: [
        if (actions != null) ...actions!,
        if (showAdminButton)
          IconButton(
            icon: const Icon(Icons.admin_panel_settings, color: Colors.orange),
            onPressed: onAdminTap,
            tooltip: "Admin Dashboard",
          ),
        if (showSupportMessage)
          IconButton(
            icon: const Icon(Icons.support_agent_rounded, color: Colors.teal),
            onPressed: onSupportTap,
            tooltip: "Support Dashboard",
          ),
        if (showProfile)
          GestureDetector(
            onTap: onProfileTap,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.primaryLight.withOpacity(0.1),
                backgroundImage: photoUrl != null && photoUrl!.isNotEmpty
                    ? NetworkImage("${BaseApiService.baseUrl.split('/api')[0]}/$photoUrl")
                    : null,
                child: photoUrl == null || photoUrl!.isEmpty
                    ? const Icon(Icons.person, size: 20, color: AppTheme.primaryLight)
                    : null,
              ),
            ),
          ),
        if (showThemeToggle)
          IconButton(
            icon: Icon(Theme.of(context).brightness == Brightness.dark 
                ? Icons.light_mode 
                : Icons.dark_mode, color: AppTheme.primaryLight),
            onPressed: onThemeToggle,
          ),
      ],
    );
  }

  Widget _buildRoleBadge(String role) {
    final bool isAdmin = role == 'admin';
    final Color color = isAdmin ? AppTheme.primaryLight : Colors.teal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}