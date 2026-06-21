import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:ui';
import '../../theme/app_theme.dart';
import '../../services/mall_api_service.dart';
import '../../services/socket_service.dart';
import '../../services/user_api_service.dart';
import '../../models/user_model.dart';
import '../../providers/reservation_provider.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../widgets/custom_app_bar.dart';
import '../../widgets/app_background.dart';

class SpotsScreen extends StatefulWidget {
  final Map<String, dynamic> mall;

  const SpotsScreen({super.key, required this.mall});

  @override
  _SpotsScreenState createState() => _SpotsScreenState();
}

class _SpotsScreenState extends State<SpotsScreen> {
  final MallApiService _apiService = MallApiService();
  List<Map<String, dynamic>> _spots = [];
  final Map<String, ValueNotifier<String>> _spotStatuses = {};
  bool _isLoading = true;
  bool _isSheetOpening = false;
  final TextEditingController _carPlateController = TextEditingController();
  TimeOfDay? _arrivalTime;
  TimeOfDay? _leavingTime;
  Timer? _refreshTimer;
  StreamSubscription? _socketSubscription;
  String _userRole = 'user';
  bool _isEditMode = false;
  final DateTime _selectedDate = DateTime.now();
  String? carPlateError;
  String? timeError;
  String? cardError;
  String? expiryError;
  String? cvvError;
  String? promoError;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _fetchSpots();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchSpots(isManual: false);
    });
    
    _socketSubscription = SocketService.spotStatusStream.listen((data) {
      final spotId = data['spotId']?.toString();
      final status = data['status']?.toString();
      final mallId = data['mallId']?.toString();
      final currentMallId = widget.mall['_id']?.toString() ?? widget.mall['id']?.toString();
      
      // Real-time Update: Filter by mallId to ensure we only update spots in the current mall
      if (spotId != null && status != null && (mallId == null || mallId == currentMallId) && _spotStatuses.containsKey(spotId)) {
        debugPrint("[SOCKET] Updating spot $spotId in mall $mallId to status $status");
        _spotStatuses[spotId]!.value = status;
      } else if (spotId != null && status != null && _spotStatuses.containsKey(spotId)) {
        // Fallback for older events that might not have mallId
         _spotStatuses[spotId]!.value = status;
      }
    });

    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userRole = prefs.getString('role') ?? 'user';
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _socketSubscription?.cancel();
    _carPlateController.dispose();
    for (var notifier in _spotStatuses.values) {
      notifier.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchSpots({bool isManual = true}) async {
    if (isManual) setState(() => _isLoading = true);
    try {
      final mallId = widget.mall['_id'] ?? widget.mall['id'].toString();
      final spots = await _apiService.getSpots(mallId);
      if (!mounted) return;
      setState(() {
        _spots = List<Map<String, dynamic>>.from(spots);
        for (var spot in _spots) {
          final id = spot['_id']?.toString() ?? spot['id']?.toString();
          final status = spot['status']?.toString() ?? 'green';
          if (id != null) {
            if (_spotStatuses.containsKey(id)) {
              _spotStatuses[id]!.value = status;
            } else {
              _spotStatuses[id] = ValueNotifier<String>(status);
            }
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load spots: $e")),
      );
    }
  }

  void _showReservationBottomSheet(Map<String, dynamic> spot) async {
    if (_isSheetOpening) return;
    setState(() => _isSheetOpening = true);

      try {
        // Fetch user profile for rewards calculation
        User? currentUser;
        try {
          currentUser = await UserApiService().getUserProfile();
          if (!mounted) return;
        } catch (e) {
          debugPrint("Error fetching user: $e");
        }

      if (_isEditMode && _userRole == 'admin') {
        final String currentStatus = spot['status'] ?? 'green';
        final String newStatus = currentStatus == 'disabled' ? 'green' : 'disabled';
        
        // Prevent disabling reserved spots (yellow/red)
        if (currentStatus == 'yellow' || currentStatus == 'red') {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot disable a reserved spot")));
          setState(() => _isSheetOpening = false);
          return;
        }

        final res = await _apiService.updateSpotStatus(
          widget.mall['_id'] ?? widget.mall['id'], 
          spot['_id'] ?? spot['id'], 
          newStatus
        );
        
        if (res['success']) {
          if (!mounted) return;
          _fetchSpots(isManual: false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Spot ${newStatus == 'disabled' ? 'Disabled' : 'Enabled'}")));
        }
        if (!mounted) return;
        setState(() => _isSheetOpening = false);
        return;
      }

      if (spot['status'] == 'disabled') {
        setState(() => _isSheetOpening = false);
        return;
      }

      _showReservationBottomSheetActual(spot, currentUser);
    } finally {
      // Reset flag after a small delay to allow for standard user interaction
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _isSheetOpening = false);
      });
    }
  }

  void _showReservationBottomSheetActual(Map<String, dynamic> spot, User? currentUser) {
    bool isPaymentStep = false;
    final cardController = TextEditingController();
    final expiryController = TextEditingController();
    final cvvController = TextEditingController();
    final promoController = TextEditingController();
    String? appliedPromo;
    double promoDiscountPerc = 0.0;
    bool isSubmitting = false;
    bool isValidatingPromo = false;

    carPlateError = null;
    timeError = null;
    cardError = null;
    expiryError = null;
    cvvError = null;
    promoError = null;
    errorMessage = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          
          double calculateRewardDiscount(double basePrice, String? reward) {
            if (reward == "25% Discount") return basePrice * 0.25;
            if (reward == "50% Discount") return basePrice * 0.50;
            if (reward == "Free Parking") {
              if (_arrivalTime == null || _leavingTime == null) return 0.0;
              final rawPrice = widget.mall['pricePerHour'];
              final double hourlyRate = (rawPrice != null && rawPrice != 0) ? rawPrice.toDouble() : 20.0;
              
              DateTime arrivalDT = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _arrivalTime!.hour, _arrivalTime!.minute);
              DateTime leavingDT = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _leavingTime!.hour, _leavingTime!.minute);
              final hours = (leavingDT.difference(arrivalDT).inMinutes / 60.0).clamp(0.0, double.infinity);
              
              const double freeHoursLimit = 4.0;
              final discountedHours = hours > freeHoursLimit ? freeHoursLimit : hours;
              return (discountedHours * hourlyRate).toDouble();
            }
            return 0.0;
          }

          double calculateBasePrice() {
            if (_arrivalTime == null || _leavingTime == null) return 0.0;
            DateTime arrivalDT = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _arrivalTime!.hour, _arrivalTime!.minute);
            DateTime leavingDT = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _leavingTime!.hour, _leavingTime!.minute);
            
            if (leavingDT.isBefore(arrivalDT)) return 0.0; // Invalid range
            
            final hours = leavingDT.difference(arrivalDT).inMinutes / 60.0;
            
            // Fallback to 20.0 if pricePerHour is 0 or null
            final rawPrice = widget.mall['pricePerHour'];
            final double hourlyRate = (rawPrice != null && rawPrice != 0) ? rawPrice.toDouble() : 20.0;
            
            return (hours.clamp(1, 24) * hourlyRate).toDouble();
          }

          final basePrice = calculateBasePrice();
          final rewardDiscount = calculateRewardDiscount(basePrice, currentUser?.pendingReward);
          
          // Real-time promo discount calculation
          final promoDiscount = ((basePrice - rewardDiscount) * promoDiscountPerc) / 100;
          
          final totalDiscount = rewardDiscount + promoDiscount;
          final totalPrice = (basePrice - totalDiscount).clamp(0.0, double.infinity);

          return Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF121212), Color(0xFF1A1A1A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(35), topRight: Radius.circular(35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.8),
                  blurRadius: 30,
                  spreadRadius: 10,
                )
              ],
              border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
            ),
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 12, left: 24, right: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- DRAG HANDLE ---
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  
                  // --- HEADER ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPaymentStep ? "Secure Payment" : "Reservation", 
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5)
                          ),
                          const SizedBox(height: 4),
                          Text("${widget.mall['name']} • Spot ${spot['spotNumber']}", style: TextStyle(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                   Row(
                     children: [
                       Icon(Icons.payments_outlined, size: 14, color: AppTheme.primaryLight.withOpacity(0.8)),
                       const SizedBox(width: 6),
                       Text(
                         "${(widget.mall['pricePerHour'] != null && widget.mall['pricePerHour'] != 0) ? widget.mall['pricePerHour'] : 20} EGP / hour", 
                         style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryLight.withOpacity(0.9))
                       ),
                     ],
                   ),
                   const SizedBox(height: 10),
                   
                   if (errorMessage != null)
                     Container(
                       padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                       margin: const EdgeInsets.only(bottom: 16),
                       decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                       child: Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600)),
                     ),

                   if (currentUser?.pendingReward != null) 
                     Container(
                       margin: const EdgeInsets.only(bottom: 10),
                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                       decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                       child: Row(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           const Icon(Icons.stars, color: Colors.green, size: 16),
                           const SizedBox(width: 6),
                           Text("${currentUser!.pendingReward} Applied!", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                         ],
                       ),
                     ),
                   
                   const SizedBox(height: 20),

                  if (!isPaymentStep) ...[
                    // --- TIME PICKERS (SIDE BY SIDE) ---
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Arrival Time", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  final picked = await showTimePicker(context: context, initialTime: _arrivalTime ?? TimeOfDay.now());
                                  if (picked != null) setSheetState(() => _arrivalTime = picked);
                                },
                                child: _buildTimeSelector(label: _arrivalTime?.format(context) ?? "--:-- --", icon: Icons.access_time_rounded),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Departure Time", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  final picked = await showTimePicker(context: context, initialTime: _leavingTime ?? TimeOfDay.now());
                                  if (picked != null) setSheetState(() => _leavingTime = picked);
                                },
                                child: _buildTimeSelector(label: _leavingTime?.format(context) ?? "--:-- --", icon: Icons.access_time_rounded),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (timeError != null) 
                      Padding(padding: const EdgeInsets.only(top: 8), child: Text(timeError!, style: const TextStyle(color: Colors.red, fontSize: 12))),

                    const SizedBox(height: 25),

                    // --- CAR PLATE ---
                    const Text("Verify Car Plate", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _carPlateController,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: "ABC-1234",
                        hintStyle: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.normal),
                        errorText: carPlateError,
                        filled: true,
                        fillColor: const Color(0xFF1E1E1E),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5)),
                        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
                        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 25),

                    // --- WARNING BANNER ---
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orange.withOpacity(0.15), width: 1),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded, color: Colors.orange.withOpacity(0.8), size: 20),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              "Overstaying your reserved time will result in a fine. Ensure you leave on time or extend your stay.",
                              style: TextStyle(color: Colors.orange.withOpacity(0.7), fontSize: 13, height: 1.5, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // --- PROCEED BUTTON ---
                    _buildActionButton(
                      text: totalPrice > 0 ? "Proceed to Payment" : "Reserve Now", 
                      isLoading: isSubmitting,
                      onPressed: isSubmitting ? null : () async {
                        final now = DateTime.now();
                        final arrivalDT = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _arrivalTime?.hour ?? 0, _arrivalTime?.minute ?? 0);
                        
                        setSheetState(() {
                          carPlateError = _carPlateController.text.isEmpty ? "Car plate is required" : null;
                          timeError = (_arrivalTime == null || _leavingTime == null) ? "Both times are required" : null;
                          
                          if (timeError == null && arrivalDT.isBefore(now.subtract(const Duration(minutes: 2)))) {
                            timeError = "Arrival time has already passed.";
                          }
                        });

                        if (carPlateError != null || timeError != null) return;

                        if (totalPrice > 0) {
                          setSheetState(() => isPaymentStep = true);
                        } else {
                          // DIRECT BOOKING (FREE)
                          setSheetState(() => isSubmitting = true);
                          final result = await _processPayment(spot, appliedPromo ?? promoController.text);
                          
                          if (mounted) {
                            if (result['success'] == true) {
                              Navigator.pop(context); 
                              _showSuccessDialog(this.context);
                            } else {
                              setSheetState(() {
                                isSubmitting = false;
                                errorMessage = result['message'] ?? "Reservation failed. Please try again.";
                              });
                            }
                          }
                        }
                      }
                    ),
                  ] else ...[
                    // --- TOTAL AMOUNT BOX (PREMIUM GLASS) ---
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Payable Amount", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 8),
                                  Text("${totalPrice.toStringAsFixed(2)} EGP", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -1)),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.green.withOpacity(0.2), Colors.green.withOpacity(0.1)],
                                  ),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.stars_rounded, color: Colors.greenAccent, size: 16),
                                    const SizedBox(width: 6),
                                    Text("+${math.max(1, (basePrice / 10).round())} pts", style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    // --- CARD NUMBER ---
                    const Text("Card Number", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: cardController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(16),
                      ],
                      decoration: InputDecoration(
                        hintText: "0000 0000 0000 0000",
                        hintStyle: TextStyle(color: Colors.grey[700]),
                        errorText: cardError != null ? "" : null,
                        errorStyle: const TextStyle(height: 0),
                        filled: true,
                        fillColor: const Color(0xFF1E1E1E),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5)),
                        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
                        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
                      ),
                    ),
                    SizedBox(
                      height: 18,
                      child: cardError != null
                        ? Padding(
                            padding: const EdgeInsets.only(top: 2, left: 4),
                            child: Text(cardError!, style: const TextStyle(color: Colors.red, fontSize: 11)),
                          )
                        : null,
                    ),
                    const SizedBox(height: 5),

                    // --- EXPIRY & CVC ---
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Expiry Date", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: expiryController,
                                style: const TextStyle(color: Colors.white),
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4), DateInputFormatter()],
                                decoration: InputDecoration(
                                  hintText: "MM/YY",
                                  hintStyle: TextStyle(color: Colors.grey[700]),
                                  errorText: expiryError != null ? "" : null,
                                  errorStyle: const TextStyle(height: 0),
                                  filled: true,
                                  fillColor: const Color(0xFF1E1E1E),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5)),
                                  errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
                                  focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
                                ),
                              ),
                              SizedBox(
                                height: 18,
                                child: expiryError != null
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 2, left: 4),
                                      child: Text(expiryError!, style: const TextStyle(color: Colors.red, fontSize: 11)),
                                    )
                                  : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("CVC", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: cvvController,
                                style: const TextStyle(color: Colors.white),
                                obscureText: true,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(3),
                                ],
                                decoration: InputDecoration(
                                  hintText: "123",
                                  hintStyle: TextStyle(color: Colors.grey[700]),
                                  errorText: cvvError != null ? "" : null,
                                  errorStyle: const TextStyle(height: 0),
                                  filled: true,
                                  fillColor: const Color(0xFF1E1E1E),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5)),
                                  errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
                                  focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
                                ),
                              ),
                              SizedBox(
                                height: 18,
                                child: cvvError != null
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 2, left: 4),
                                      child: Text(cvvError!, style: const TextStyle(color: Colors.red, fontSize: 11)),
                                    )
                                  : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // --- PROMO CODE ---
                    if (appliedPromo == null)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: promoController,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: "Promo Code",
                                hintStyle: TextStyle(color: Colors.grey[700]),
                                filled: true,
                                fillColor: const Color(0xFF1A1A1A),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          TextButton(
                            onPressed: isValidatingPromo ? null : () async {
                               // Promo logic...
                               setSheetState(() { isValidatingPromo = true; promoError = null; });
                               final result = await Provider.of<ReservationProvider>(context, listen: false).validatePromoCode(promoController.text.trim());
                               if (mounted) {
                                 setSheetState(() {
                                 isValidatingPromo = false;
                                 if (result['success'] == true) { appliedPromo = result['code']; promoDiscountPerc = (result['discount'] ?? 0).toDouble(); }
                                 else { promoError = result['message']; }
                               });
                               }
                            },
                            child: Text(isValidatingPromo ? "..." : "Apply", style: const TextStyle(color: Color(0xFF6366F1))),
                          ),
                        ],
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 16),
                            const SizedBox(width: 10),
                            Text("Promo $appliedPromo Applied!", style: const TextStyle(color: Colors.green, fontSize: 13)),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 10),
                    if (isPaymentStep)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 25),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.security_rounded, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 6),
                            Text("Secure 256-bit SSL Encrypted Payment", style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),

                    // --- FINAL BUTTON ---
                    _buildActionButton(
                      text: "Pay & Reserve", 
                      isLoading: isSubmitting,
                      onPressed: isSubmitting ? null : () async {
                          setSheetState(() {
                            cardError = cardController.text.length != 16 ? "Card number must be 16 digits" : null;
                            expiryError = (expiryController.text.isEmpty || !isExpiryValid(expiryController.text)) ? "Invalid Date" : null;
                            cvvError = cvvController.text.length < 3 ? "Invalid" : null;
                          });

                          if (cardError != null || expiryError != null || cvvError != null) return;
                          setSheetState(() => isSubmitting = true);
                          
                          final now = DateTime.now();
                          DateTime arrivalDT = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _arrivalTime!.hour, _arrivalTime!.minute);
                          DateTime leavingDT = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _leavingTime!.hour, _leavingTime!.minute);
                          
                          if (arrivalDT.isBefore(now.subtract(const Duration(minutes: 2)))) {
                             setSheetState(() {
                               isSubmitting = false;
                               isPaymentStep = false; // Go back to selection
                               timeError = "Arrival time has already passed.";
                             });
                             return;
                          }
  
                          // Strict Validation: Leaving must be after arrival
                          if (!leavingDT.isAfter(arrivalDT)) {
                            setSheetState(() {
                              isSubmitting = false;
                              isPaymentStep = false; // Go back to selection
                              timeError = "Leaving time must be after arrival time.";
                            });
                            return;
                          }

                          try {
                            final result = await _processPayment(spot, appliedPromo ?? promoController.text);
                            
                            if (mounted) {
                              if (result['success'] == true) {
                                // 1. Close the bottom sheet (the payment sheet)
                                Navigator.pop(context); 
                                
                                // 2. Show Success Dialog using the root context
                                _showSuccessDialog(this.context);
                              } else {
                                setSheetState(() {
                                  isSubmitting = false;
                                  errorMessage = result['message'] ?? "Payment failed. Please try again.";
                                });
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              setSheetState(() {
                                isSubmitting = false;
                                errorMessage = "An error occurred: $e";
                              });
                            }
                          }
                        }
                    ),
                    if (!isSubmitting) TextButton(onPressed: () => setSheetState(() => isPaymentStep = false), child: const Text("Back to selection")),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 30),
              SizedBox(width: 10),
              Text("Success Reservation", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Your reservation has been confirmed successfully!",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 15),
              Text(
                "• Please arrive at your spot 15 minutes before your scheduled time.",
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 8),
              Text(
                "• Once you arrive, please verify your arrival in the Activity screen.",
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK", style: TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>> _processPayment(Map<String, dynamic> spot, String promoCode) async {
    DateTime arrivalDT = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _arrivalTime!.hour, _arrivalTime!.minute);
    DateTime leavingDT = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _leavingTime!.hour, _leavingTime!.minute);

    final reservationData = {
      'spotId': spot['_id'] ?? spot['id'],
      'mallId': widget.mall['_id'] ?? widget.mall['id'],
      'carPlate': _carPlateController.text,
      'startTime': arrivalDT.toUtc().toIso8601String(),
      'endTime': leavingDT.toUtc().toIso8601String(),
      'promoCode': promoCode,
    };

    return await Provider.of<ReservationProvider>(context, listen: false).createReservation(reservationData);
  }

  Widget _buildPriceRow(String label, String value, {bool isDiscount = false, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isTotal ? 18 : 14, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: isTotal ? 18 : 14, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, color: isDiscount ? Colors.green : (isTotal ? AppTheme.primaryLight : Colors.black))),
        ],
      ),
    );
  }


  Widget _buildActionButton({required String text, required VoidCallback? onPressed, bool isLoading = false}) {
    return Container(
      width: double.infinity,
      height: 62,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: onPressed != null && !isLoading
            ? const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        color: onPressed == null || isLoading ? Colors.grey[800] : null,
        boxShadow: [
          if (!isLoading && onPressed != null)
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 0,
        ),
        child: isLoading 
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
            : Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
      ),
    );
  }

  Widget _buildTimeSelector({required String label, required IconData icon, bool isError = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border.all(
          color: isError ? Colors.red : Colors.white.withOpacity(0.08),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isError)
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label, 
            style: TextStyle(
              color: label.contains(':') ? Colors.white : Colors.grey[600], 
              fontSize: 16, 
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            )
          ),
          Icon(icon, color: AppTheme.primaryLight.withOpacity(0.7), size: 22),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent, // Background handled by AppBackground
        appBar: CustomAppBar(
          title: _isEditMode ? "Quick Edit Mode" : (widget.mall['name'] ?? "Parking Spots"),
          showBackButton: true,
          showProfile: false,
          onProfileTap: () => Navigator.pushNamed(context, '/profile'),
          actions: [
            if (_userRole == 'admin')
              IconButton(
                icon: Icon(_isEditMode ? Icons.check_circle : Icons.edit, color: AppTheme.primaryLight),
                onPressed: () => setState(() => _isEditMode = !_isEditMode),
                tooltip: _isEditMode ? "Finish Editing" : "Quick Edit Spots",
              ),
          ],
        ),
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.primaryLight.withOpacity(0.3)),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.spaceEvenly,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _buildLegendItem("Available", Colors.green),
                            _buildLegendItem("Ending Soon", Colors.amber),
                            _buildLegendItem("Reserved", Colors.red),
                            _buildLegendItem("Disabled", Colors.grey[300]!),
                          ],
                        ),
                      ).animate().fadeIn(duration: 500.ms),
                      const SizedBox(height: 20),
                      Expanded(
                        child: RepaintBoundary(
                          child: GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 5,
                              childAspectRatio: 0.8,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: _spots.length,
                            itemBuilder: (context, index) {
                              final spot = _spots[index];
                              final id = spot['_id']?.toString() ?? spot['id']?.toString();
                              return SpotWidget(
                                initialSpot: spot,
                                statusNotifier: _spotStatuses[id]!,
                                onTap: () => _showReservationBottomSheet(spot),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

bool isExpiryValid(String value) {
  if (value.length != 5) return false;
  final parts = value.split('/');
  if (parts.length != 2) return false;
  
  final month = int.tryParse(parts[0]);
  final yearStr = parts[1];
  final yearShort = int.tryParse(yearStr);
  
  if (month == null || yearShort == null) return false;
  if (month < 1 || month > 12) return false;
  
  final now = DateTime.now();
  final currentYearFull = now.year;
  final currentMonth = now.month;
  
  // Convert 2-digit year to full year (20XX)
  final yearFull = 2000 + yearShort;
  
  if (yearFull < currentYearFull) return false;
  if (yearFull == currentYearFull && month < currentMonth) return false;
  
  return true;
}

class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
        buffer.write(text[i]);
        var nonZeroIndex = i + 1;
        if (nonZeroIndex % 2 == 0 && nonZeroIndex != text.length) {
            buffer.write('/');
        }
    }

    var string = buffer.toString();
    return newValue.copyWith(
        text: string,
        selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

class SpotWidget extends StatelessWidget {
  final Map<String, dynamic> initialSpot;
  final ValueNotifier<String> statusNotifier;
  final VoidCallback onTap;

  const SpotWidget({
    super.key, 
    required this.initialSpot, 
    required this.statusNotifier, 
    required this.onTap
  });

  Color _getColor(String status) {
    switch (status) {
      case 'green': return Colors.green;
      case 'yellow': return Colors.amber;
      case 'red': return Colors.red;
      case 'disabled': return Colors.grey[300]!;
      default: return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: statusNotifier,
      builder: (context, status, child) {
        final bool isDisabled = status == 'disabled';
        // Allow tap if green, or if admin is in edit mode
        final isEditMode = context.findAncestorStateOfType<_SpotsScreenState>()?._isEditMode ?? false;
        bool canTap = (status == 'green' && !isEditMode) || isEditMode;
        
        return GestureDetector(
          onTap: canTap ? onTap : null,
          child: Container(
            decoration: BoxDecoration(
              color: _getColor(status),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: _getColor(status).withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    initialSpot['spotNumber'].toString(),
                    style: TextStyle(
                      color: (status == 'red') ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (isDisabled)
                    const Text(
                      "disabled",
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 300.ms).scale(),
        );
      },
    );
  }
}

