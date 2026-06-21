// lib/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:ui';
import '../../main.dart';
import '../../services/mall_api_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../theme/app_theme.dart';
// import 'package:flutter_animate/flutter_animate.dart';
import '../activity/activity_screen.dart';
import '../rewards/rewards_screen.dart';
import '../profile/profile_screen.dart';
import '../../services/socket_service.dart';
import '../../providers/reservation_provider.dart';
import '../../widgets/responsive_layout.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Widget> _screens = const [
    HomeScreenContent(),
    ActivityScreen(),
    RewardsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _onTabTapped(int index) {
    context.read<ReservationProvider>().setTab(index);
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = context.select<ReservationProvider, int>((p) => p.selectedTab);
    
    return PopScope(
      canPop: currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && currentIndex != 0) {
          context.read<ReservationProvider>().setTab(0);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent, 
        extendBody: true,
        body: IndexedStack(
          index: currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: _buildAnimatedBottomNav(context, currentIndex),
      ),
    );
  }

  Widget _buildAnimatedBottomNav(BuildContext context, int currentIndex) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = ResponsiveLayout.isTablet(context) || ResponsiveLayout.isDesktop(context);
    
    // Constrain width on tablets
    final double navWidth = isTablet ? 500 : screenWidth - 32;
    const double navHeight = 65;
    final double itemWidth = navWidth / 4;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Container(
          width: navWidth,
          height: navHeight,
          decoration: BoxDecoration(
            color: isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.25),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutQuart,
                    left: currentIndex * itemWidth,
                    top: 10,
                    bottom: 10,
                    child: Container(
                      width: itemWidth,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.primaryLight.withOpacity(0.2)),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(child: _buildNavItem(0, Icons.home_outlined, Icons.home, "Home", currentIndex)),
                      Expanded(child: _buildNavItem(1, Icons.history_outlined, Icons.history, "Activity", currentIndex)),
                      Expanded(child: _buildNavItem(2, Icons.card_giftcard_outlined, Icons.card_giftcard, "Rewards", currentIndex)),
                      Expanded(child: _buildNavItem(3, Icons.person_outline, Icons.person, "Profile", currentIndex)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label, int currentIndex) {
    final bool isActive = currentIndex == index;
    
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isActive ? activeIcon : icon,
            color: isActive ? AppTheme.primaryLight : Colors.grey,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? AppTheme.primaryLight : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class MallCard extends StatelessWidget {
  final Map<String, dynamic> mall;
  final int index;

  const MallCard({
    super.key,
    required this.mall,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final totalSpots = mall['totalSpots']?.toString() ?? "0";
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primaryLight.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.25),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: InkWell(
          onTap: () async {
            final homeState = context.findAncestorStateOfType<_HomeScreenContentState>();
            if (homeState != null) {
              if (homeState.isNavigating) return;
              homeState.setNavigating(true);
              
              await Navigator.pushNamed(context, '/spots', arguments: mall);
              
              if (homeState.mounted) homeState.setNavigating(false);
            } else {
              Navigator.pushNamed(context, '/spots', arguments: mall);
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                   ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: (mall['photoUrl'] != null && mall['photoUrl'] != "")
                        ? Image.network(
                            mall['photoUrl'],
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            cacheWidth: 800,
                            errorBuilder: (ctx, obj, st) => Container(
                              height: 180,
                              color: Colors.grey[800],
                              child: const Icon(Icons.business, size: 50, color: Colors.grey),
                            ),
                          )
                        : Container(
                            height: 180,
                            color: Colors.grey[800],
                            child: const Icon(Icons.business, size: 50, color: Colors.grey),
                          ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "$totalSpots spots",
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mall['name'] ?? "Mall",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          mall['location'] ?? "Location",
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreenContent extends StatefulWidget {
  const HomeScreenContent({super.key});

  @override
  _HomeScreenContentState createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<HomeScreenContent> {
  final MallApiService _apiService = MallApiService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String? _photoUrl;
  List<Map<String, dynamic>> _malls = [];
  List<Map<String, dynamic>> _filteredMalls = [];
  bool _isLoading = true;
  bool _isNavigating = false;
  bool get isNavigating => _isNavigating;
  void setNavigating(bool val) => setState(() => _isNavigating = val);
  String _errorMessage = '';
  StreamSubscription? _mallSubscription;

  @override
  void initState() {
    super.initState();
    _fetchMalls();
    _initMallListeners();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _initMallListeners() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _photoUrl = prefs.getString('photoUrl');
      });
    }
    _mallSubscription = SocketService.mallStream.listen((data) {
      _fetchMalls(showLoading: false);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _mallSubscription?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final query = _searchController.text.toLowerCase();
      setState(() {
        _filteredMalls = _malls.where((mall) {
          final name = (mall['name'] ?? '').toLowerCase();
          final location = (mall['location'] ?? '').toLowerCase();
          return name.startsWith(query) || location.contains(query);
        }).toList();
      });
    });
  }

  Future<void> _fetchMalls({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    try {
      final malls = await _apiService.getMalls();
      if (!mounted) return;
      setState(() {
        _malls = malls;
        _filteredMalls = _malls.where((mall) {
          final query = _searchController.text.toLowerCase();
          final name = (mall['name'] ?? '').toLowerCase();
          final location = (mall['location'] ?? '').toLowerCase();
          return name.startsWith(query) || location.contains(query);
        }).toList();
        _isLoading = false;
        _errorMessage = '';
      });
    } catch (e) {
      debugPrint('[HOME ERROR] Failed to fetch malls: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load malls: ${e.toString().replaceAll('Exception: ', '')}';
      });
    }
  }

  void _navigateToAdmin(String role) {
    if (role == 'admin') {
      Navigator.pushNamed(context, '/admin');
    }
  }

  void _toggleTheme() {
    final appState = context.findAncestorStateOfType<IparkAppState>();
    appState?.toggleTheme();
  }

  @override
  Widget build(BuildContext context) {
    final userRole = context.select<ReservationProvider, String>((p) => p.userRole);
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      appBar: CustomAppBar(
        title: "iPark",
        showBackButton: false,
        showProfile: true,
        photoUrl: _photoUrl,
        role: userRole,
        showSupportMessage: userRole == 'support',
        showAdminButton: userRole == 'admin',
        onProfileTap: () => Navigator.pushNamed(context, '/profile'),
        onSupportTap: () => Navigator.pushNamed(context, '/support'),
        onAdminTap: () => _navigateToAdmin(userRole),
        showThemeToggle: true,
        onThemeToggle: _toggleTheme,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search for a Mall...",
                prefixIcon: const Icon(Icons.search, color: AppTheme.primaryLight),
                suffixIcon: _searchController.text.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
                : _errorMessage.isNotEmpty
                    ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
                    : RefreshIndicator(
                        onRefresh: () async => _fetchMalls(showLoading: false),
                        color: AppTheme.primaryLight,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final bool isTablet = constraints.maxWidth > 600;
                            final int crossAxisCount = isTablet ? 2 : 1;
                            final double childAspectRatio = isTablet ? 1.1 : 1.4;

                            if (isTablet) {
                              return GridView.builder(
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 0,
                                  childAspectRatio: childAspectRatio,
                                ),
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: _filteredMalls.length,
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                                itemBuilder: (context, index) => MallCard(mall: _filteredMalls[index], index: index),
                              );
                            }

                            return ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: _filteredMalls.length,
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                              itemBuilder: (context, index) => MallCard(mall: _filteredMalls[index], index: index),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}