import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/otp_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/home/mall_detail_screen.dart';
import '../screens/spots/spots_screen.dart';
import '../screens/activity/activity_screen.dart';
import '../screens/rewards/rewards_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/admin/dashboard_screen.dart';
import '../screens/admin/user_list_screen.dart';
import '../screens/admin/user_detail_screen.dart';
import '../screens/support/contact_support_screen.dart';
import '../screens/admin/support_tickets_screen.dart';
import '../screens/admin/chat_list_screen.dart';
import '../screens/admin/admin_chat_screen.dart';
import '../screens/support/support_dashboard.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
    case '/splash':
      print('[ROUTER] Navigating to /splash');
      return MaterialPageRoute(builder: (_) => const SplashScreen());
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case '/otp':
        final phoneNumber = settings.arguments as String? ?? '';
        return MaterialPageRoute(
          builder: (_) => OtpScreen(phoneNumber: phoneNumber),
        );
      case '/register':
        final phoneNumber = settings.arguments as String? ?? '';
        return MaterialPageRoute(
          builder: (_) => RegisterScreen(phoneNumber: phoneNumber),
        );
      case '/':
      case '/home':
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case '/mall-detail':
        final mall = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => MallDetailScreen(mall: mall),
        );
      case '/activity':
        return MaterialPageRoute(builder: (_) => const ActivityScreen());
      case '/rewards':
        return MaterialPageRoute(builder: (_) => const RewardsScreen());
      case '/profile':
        final showBack = settings.arguments as bool? ?? true;
        return MaterialPageRoute(builder: (_) => ProfileScreen(showBackButton: showBack));
      case '/spots':
        final mall = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(builder: (_) => SpotsScreen(mall: mall));
      case '/admin':
        return MaterialPageRoute(builder: (_) => const AdminDashboard());
      case '/admin/users':
        return MaterialPageRoute(builder: (_) => const UserListScreen());
      case '/admin/user-details':
        final user = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(builder: (_) => UserDetailScreen(user: user));
      case '/messages':
      case '/admin/support':
        return MaterialPageRoute(builder: (_) => const SupportTicketsScreen());
      case '/contact-support':
        return MaterialPageRoute(builder: (_) => const ContactSupportScreen());
      case '/support':
        return MaterialPageRoute(builder: (_) => const SupportDashboard());
      case '/admin/chat-list':
        return MaterialPageRoute(builder: (_) => const AdminChatListScreen());
      case '/admin/chat':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => AdminChatScreen(
            userId: args['userId'],
            userName: args['userName'],
            user: args['user'] ?? {},
          ),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Navigation Error')),
            body: Center(
              child: Text(
                'No route defined for: "${settings.name ?? 'null'}"',
                style: const TextStyle(fontSize: 16, color: Colors.red),
              ),
            ),
          ),
        );
    }
  }
}
