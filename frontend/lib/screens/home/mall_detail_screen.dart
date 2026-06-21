// lib/screens/home/mall_detail_screen.dart
import 'package:flutter/material.dart';
import '../../widgets/custom_app_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MallDetailScreen extends StatefulWidget {
  final Map<String, dynamic> mall;

  const MallDetailScreen({super.key, required this.mall});

  @override
  State<MallDetailScreen> createState() => _MallDetailScreenState();
}

class _MallDetailScreenState extends State<MallDetailScreen> {
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: widget.mall['name'] ?? "Mall Details",
        showBackButton: true,
        photoUrl: _photoUrl,
        onProfileTap: () => Navigator.pushNamed(context, '/profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mall Photo
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                widget.mall['photoUrl'] ?? 'https://via.placeholder.com/400x200',
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.mall['name'] ?? "Mall Name",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red),
                const SizedBox(width: 5),
                Text(widget.mall['location'] ?? "Location"),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              "Available Spots: ${widget.mall['totalSpots'] ?? 50}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.payments_outlined, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Price: ${(widget.mall['pricePerHour'] != null && widget.mall['pricePerHour'] != 0) ? widget.mall['pricePerHour'] : 20} EGP / hour",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[900]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/spots', arguments: widget.mall),
              child: const Text("View Available Spots"),
            ),
          ],
        ),
      ),
    );
  }
}