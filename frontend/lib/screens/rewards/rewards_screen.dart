import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/user_api_service.dart';
import '../../widgets/car_loader.dart';
import '../../widgets/custom_app_bar.dart';
import '../../main.dart';
import 'package:intl/intl.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  _RewardsScreenState createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  final UserApiService _apiService = UserApiService();
  List<Map<String, dynamic>> _history = [];
  int _totalPoints = 0;
  bool _isLoading = true;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadProfilePhoto();
  }

  Future<void> _loadProfilePhoto() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _photoUrl = prefs.getString('photoUrl');
      });
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = await _apiService.getUserProfile();
      final history = await _apiService.getPointHistory();
      
      if (mounted) {
        setState(() {
          _totalPoints = user.points;
          _history = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exchange(int amount, String rewardName) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final res = await _apiService.exchangePoints(amount, rewardName);
    
    if (mounted) {
      Navigator.pop(context); 
      if (res['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Successfully redeemed $rewardName!")),
        );
        _loadData(); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? "Exchange failed"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _toggleTheme() {
    final appState = context.findAncestorStateOfType<IparkAppState>();
    appState?.toggleTheme();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      appBar: CustomAppBar(
        title: "My Rewards",
        showBackButton: false,
        photoUrl: _photoUrl,
        showThemeToggle: true,
        onProfileTap: () => Navigator.pushNamed(context, '/profile'),
        onThemeToggle: _toggleTheme,
      ),
      body: _isLoading 
        ? const CarLoader(message: "Calculating your points...")
        : RefreshIndicator(
            onRefresh: _loadData,
            color: AppTheme.primaryLight,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PointsCard(points: _totalPoints),
                  const SizedBox(height: 30),
                  const Text(
                    "Available Offers",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 15),
                  OfferItem(title: "25% Discount", points: 50, icon: Icons.percent, totalPoints: _totalPoints, onRedeem: () => _showConfirmExchange("25% Discount", 50)),
                  OfferItem(title: "50% Discount", points: 100, icon: Icons.discount, totalPoints: _totalPoints, onRedeem: () => _showConfirmExchange("50% Discount", 100)),
                  OfferItem(title: "Free Parking", points: 200, icon: Icons.local_parking, totalPoints: _totalPoints, onRedeem: () => _showConfirmExchange("Free Parking", 200)),
                  const SizedBox(height: 30),
                  const Text(
                    "Point History",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 15),
                  _history.isEmpty 
                    ? _buildEmptyHistory()
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _history.length,
                        itemBuilder: (context, index) => HistoryItem(item: _history[index], index: index),
                      ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildEmptyHistory() {
    return const Center(
      child: Column(
        children: [
          Icon(Icons.history_toggle_off, size: 50, color: Colors.grey),
          SizedBox(height: 10),
          Text("No history yet", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  void _showConfirmExchange(String reward, int cost) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Redemption"),
        content: Text("Are you sure you want to spend $cost points for $reward?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _exchange(cost, reward);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryLight),
            child: const Text("Redeem Now"),
          ),
        ],
      ),
    );
  }
}

class _PointsCard extends StatelessWidget {
  final int points;
  const _PointsCard({required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryLight, AppTheme.primaryLight.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryLight.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "Current Balance",
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.stars_rounded, color: Colors.amber, size: 40),
              const SizedBox(width: 10),
              Text(
                "$points",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 50,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            "Keep parking to earn more!",
            style: TextStyle(color: Colors.white60, fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

class OfferItem extends StatelessWidget {
  final String title;
  final int points;
  final IconData icon;
  final int totalPoints;
  final VoidCallback onRedeem;

  const OfferItem({
    super.key,
    required this.title,
    required this.points,
    required this.icon,
    required this.totalPoints,
    required this.onRedeem,
  });

  @override
  Widget build(BuildContext context) {
    bool canAfford = totalPoints >= points;
    return RepaintBoundary(
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.primaryLight.withOpacity(0.1),
            child: Icon(icon, color: AppTheme.primaryLight),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("$points Points", style: TextStyle(color: canAfford ? Colors.green : Colors.red)),
          trailing: ElevatedButton(
            onPressed: canAfford ? onRedeem : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryLight,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text("Redeem"),
          ),
        ),
      ),
    );
  }
}

class HistoryItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final int index;

  const HistoryItem({
    super.key,
    required this.item,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final amount = item['amount'] ?? 0;
    final isEarned = amount > 0;
    final date = DateTime.parse(item['createdAt']).toLocal();
    final theme = Theme.of(context);
    
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: AppTheme.primaryLight.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isEarned ? Colors.green : Colors.red).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isEarned ? Icons.add_rounded : Icons.remove_rounded,
                color: isEarned ? Colors.green : Colors.red,
                size: 20,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['reason'] ?? "Points Transaction", 
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM dd, yyyy • HH:mm').format(date), 
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              "${isEarned ? '+' : ''}$amount",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isEarned ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}