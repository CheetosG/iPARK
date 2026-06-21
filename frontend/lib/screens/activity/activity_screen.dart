import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../providers/reservation_provider.dart';
import '../../widgets/car_loader.dart';
import '../../widgets/custom_app_bar.dart';
import '../../main.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  _ActivityScreenState createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final TextEditingController _verifyController = TextEditingController();
  Timer? _uiRefreshTimer; 
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ReservationProvider>(context, listen: false).fetchReservations();
    });

    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) setState(() {});
    });
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

  void _toggleTheme() {
    final appState = context.findAncestorStateOfType<IparkAppState>();
    appState?.toggleTheme();
  }

  @override
  void dispose() {
    _uiRefreshTimer?.cancel();
    _verifyController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    await Provider.of<ReservationProvider>(context, listen: false).fetchReservations();
  }

  void _verifyArrival(Map<String, dynamic> reservation) {
    _verifyController.clear();
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (ctx) {
        bool isSubmitting = false;
        String? errorText;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with Close Button
                    Stack(
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.close, color: Colors.white.withOpacity(0.4), size: 20),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.center,
                          child: Container(
                            width: 72,
                            height: 72,
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryLight.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.directions_car_filled_rounded, color: AppTheme.primaryLight, size: 36),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Verify Arrival",
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Enter your plate number to unlock your spot",
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    // Input Field
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: errorText != null ? Colors.red.withOpacity(0.08) : Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: errorText != null ? Colors.red.withOpacity(0.8) : Colors.white.withOpacity(0.1),
                          width: errorText != null ? 1.5 : 1,
                        ),
                        boxShadow: errorText != null ? [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 2,
                          )
                        ] : null,
                      ),
                      child: TextField(
                        controller: _verifyController,
                        textAlign: TextAlign.center,
                        autofocus: true,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 4,
                        ),
                        onChanged: (_) {
                          if (errorText != null) setDialogState(() => errorText = null);
                        },
                        decoration: InputDecoration(
                          hintText: "ABC-1234",
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.15), letterSpacing: 2),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    const SizedBox(height: 32),
                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : () async {
                          final input = _verifyController.text.trim().toUpperCase();
                          final actual = (reservation['carPlate'] ?? '').toString().toUpperCase();

                          if (input == actual) {
                            setDialogState(() => isSubmitting = true);
                            try {
                              await Provider.of<ReservationProvider>(context, listen: false)
                                  .updateStatus((reservation['_id'] ?? reservation['id']).toString(), 'Active');
                              if (context.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Arrival Verified! Welcome."),
                                    backgroundColor: AppTheme.primaryLight,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                setDialogState(() {
                                  isSubmitting = false;
                                  errorText = "Verification failed. Try again.";
                                });
                              }
                            }
                          } else {
                            setDialogState(() => errorText = "Incorrect plate number");
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryLight,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        child: isSubmitting 
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                          : const Text(
                              "Verify & Park",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmCancel(Map<String, dynamic> reservation) {
    showDialog(
      context: context,
      builder: (ctx) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Cancel Reservation?"),
              content: const Text("Are you sure you want to cancel this reservation?"),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx), 
                  child: const Text("No, Keep it")
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : () async {
                    setDialogState(() => isSubmitting = true);
                    try {
                      await Provider.of<ReservationProvider>(context, listen: false)
                          .updateStatus((reservation['_id'] ?? reservation['id']).toString(), 'Cancelled Early');
                      if (context.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      debugPrint("Cancel error: $e");
                    } finally {
                      if (context.mounted) setDialogState(() => isSubmitting = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: isSubmitting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("Yes, Cancel", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmLeaveEarly(Map<String, dynamic> reservation) {
    showDialog(
      context: context,
      builder: (ctx) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Leave Early?"),
              content: const Text("Mark this spot as free and end your session?"),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx), 
                  child: const Text("Cancel")
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : () async {
                    setDialogState(() => isSubmitting = true);
                    try {
                      await Provider.of<ReservationProvider>(context, listen: false)
                          .updateStatus((reservation['_id'] ?? reservation['id']).toString(), 'Cancelled Early');
                      if (context.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      debugPrint("Leave early error: $e");
                    } finally {
                      if (context.mounted) setDialogState(() => isSubmitting = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: isSubmitting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("Confirm", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _reverifyPlate(Map<String, dynamic> reservation) {
    final TextEditingController plateController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (ctx) {
        bool isSubmitting = false;
        String? errorText;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.close, color: Colors.white.withOpacity(0.4), size: 20),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.center,
                          child: Container(
                            width: 72,
                            height: 72,
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.verified_user_rounded, color: Colors.orange, size: 36),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Re-verify Plate",
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Enter your plate number to re-open the gate",
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: errorText != null ? Colors.red.withOpacity(0.08) : Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: errorText != null ? Colors.red.withOpacity(0.8) : Colors.white.withOpacity(0.1),
                          width: errorText != null ? 1.5 : 1,
                        ),
                        boxShadow: errorText != null ? [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 2,
                          )
                        ] : null,
                      ),
                      child: TextField(
                        controller: plateController,
                        textAlign: TextAlign.center,
                        autofocus: true,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 4,
                        ),
                        onChanged: (_) {
                          if (errorText != null) setDialogState(() => errorText = null);
                        },
                        decoration: InputDecoration(
                          hintText: "ABC-1234",
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.15), letterSpacing: 2),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : () async {
                          final input = plateController.text.trim();
                          if (input.isEmpty) {
                            setDialogState(() => errorText = "Please enter your plate number");
                            return;
                          }
                          setDialogState(() => isSubmitting = true);
                          try {
                            final provider = Provider.of<ReservationProvider>(context, listen: false);
                            final result = await provider.reverifyPlate(
                              (reservation['_id'] ?? reservation['id']).toString(), input,
                            );
                            if (result['success'] == true) {
                              if (context.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Plate verified! Gate is opening."),
                                    backgroundColor: AppTheme.primaryLight,
                                  ),
                                );
                              }
                            } else {
                              setDialogState(() {
                                isSubmitting = false;
                                errorText = result['message'] ?? "Incorrect plate number";
                              });
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                              errorText = "Verification failed. Try again.";
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        child: isSubmitting 
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                          : const Text(
                              "Re-verify & Open Gate",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      appBar: CustomAppBar(
        title: "My Activity",
        showBackButton: false,
        photoUrl: _photoUrl,
        showThemeToggle: true,
        onProfileTap: () => Navigator.pushNamed(context, '/profile'),
        onThemeToggle: _toggleTheme,
      ),
      body: Consumer<ReservationProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.reservations.isEmpty) {
            return const CarLoader();
          }

          if (provider.errorMessage != null && provider.reservations.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.signal_wifi_off, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(provider.errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refreshData,
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryLight),
                      child: const Text("Retry Connection", style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            );
          }

          if (provider.reservations.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refreshData,
              color: AppTheme.primaryLight,
              child: ListView(
                children: [
                   SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                   const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_outlined, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text("No history found", style: TextStyle(fontSize: 18, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshData,
            color: AppTheme.primaryLight,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              itemCount: provider.reservations.length,
              itemBuilder: (context, index) {
                return ReservationCard(
                  reservation: provider.reservations[index],
                  index: index,
                  onVerify: () => _verifyArrival(provider.reservations[index]),
                  onCancel: () => _confirmCancel(provider.reservations[index]),
                  onLeaveEarly: () => _confirmLeaveEarly(provider.reservations[index]),
                  onReverify: () => _reverifyPlate(provider.reservations[index]),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class ReservationCard extends StatelessWidget {
  final Map<String, dynamic> reservation;
  final int index;
  final VoidCallback onVerify;
  final VoidCallback onCancel;
  final VoidCallback onLeaveEarly;
  final VoidCallback onReverify;

  const ReservationCard({
    super.key,
    required this.reservation,
    required this.index,
    required this.onVerify,
    required this.onCancel,
    required this.onLeaveEarly,
    required this.onReverify,
  });

  @override
  Widget build(BuildContext context) {
    final status = reservation['status']?.toString().toLowerCase() ?? 'pending';
    final bool isActive = status == 'active';
    final bool isPending = status == 'pending';

    DateTime? endTime;
    try {
      final rawEnd = reservation['endTime'] ?? reservation['leavingTime'];
      if (rawEnd != null) endTime = DateTime.parse(rawEnd.toString()).toLocal();
    } catch (_) {}
    
    final bool isPastTime = endTime == null ? true : DateTime.now().isAfter(endTime);
    if (endTime == null) return const SizedBox.shrink();

    String displayStatus = status.toString().toUpperCase();
    if (isActive && isPastTime) displayStatus = "EXPIRED";

    String timeLeftStr = '';
    if (isActive) {
      final diff = endTime.difference(DateTime.now());
      if (diff.inSeconds > 0) {
        timeLeftStr = '${diff.inHours}h ${(diff.inMinutes % 60).toString().padLeft(2, '0')}m remaining';
      } else {
        timeLeftStr = 'Time Expired';
      }
    }

    String formatTime(String? iso) {
      if (iso == null) return "N/A";
      try {
        final dt = DateTime.parse(iso).toLocal();
        return DateFormat('HH:mm').format(dt);
      } catch (e) { return "N/A"; }
    }

    DateTime? startTime;
    try {
      final rawStart = reservation['startTime'] ?? reservation['arrivalTime'];
      if (rawStart != null) startTime = DateTime.parse(rawStart.toString()).toLocal();
    } catch (_) {}

    final bool canVerify = startTime == null ? false : DateTime.now().isAfter(startTime.subtract(const Duration(minutes: 15)));
    final String availableInStr = startTime != null && !canVerify 
        ? "Available from ${DateFormat('HH:mm').format(startTime.subtract(const Duration(minutes: 15)))}"
        : "";

    return RepaintBoundary(
      child: Card(
        elevation: 3,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (reservation['mallId'] is Map) ? (reservation['mallId']['name'] ?? "Mall") : (reservation['mallName'] ?? "Mall"), 
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryLight),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          "Spot #${(reservation['spotId'] is Map) ? (reservation['spotId']['spotNumber'] ?? '?') : (reservation['spotNumber'] ?? '?')}", 
                          style: const TextStyle(color: Colors.grey)
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _getStatusColor(displayStatus).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(displayStatus, style: TextStyle(color: _getStatusColor(displayStatus), fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
              const Divider(height: 25),
              _buildInfoRow(Icons.login, "Arrival", formatTime(reservation['arrivalTime'] ?? reservation['startTime'])),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.logout, "Leaving", formatTime(reservation['leavingTime'] ?? reservation['endTime'])),
              if (isActive && timeLeftStr.isNotEmpty) ...[
                const Divider(height: 25),
                Text(timeLeftStr, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isPastTime ? Colors.red : AppTheme.primaryLight)),
              ],
              const SizedBox(height: 15),
              if (isPending) ... [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onCancel,
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                        child: const Text("Cancel"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: canVerify ? onVerify : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canVerify ? AppTheme.primaryLight : Colors.grey[300],
                          disabledBackgroundColor: Colors.grey[200],
                          elevation: canVerify ? 2 : 0,
                        ),
                        child: Text("VERIFY", style: TextStyle(color: canVerify ? Colors.white : Colors.grey[500])),
                      ),
                    ),
                  ],
                ),
                if (availableInStr.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(availableInStr, style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w500)),
                  ),
              ],

              if (isActive && !isPastTime)
                Row(
                  children: [
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final bool isGateOpen = reservation['gateOpened'] == true;
                          return ElevatedButton.icon(
                            onPressed: () async {
                              final provider = Provider.of<ReservationProvider>(context, listen: false);
                              final resId = (reservation['_id'] ?? reservation['id']).toString();
                              
                              // Trigger the open or close gate action
                              final result = isGateOpen 
                                  ? await provider.closeGate(resId)
                                  : await provider.openGate(resId);
                                  
                              if (result['success'] == true) {
                                // Fetch updated reservations to refresh gateOpened state
                                await provider.fetchReservations();
                              }
                              
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(result['message'] ?? (isGateOpen ? "Close command sent" : "Open command sent")),
                                    backgroundColor: result['success'] == true ? AppTheme.primaryLight : Colors.red,
                                  ),
                                );
                              }
                            },
                            icon: Icon(isGateOpen ? Icons.lock : Icons.lock_open, size: 16),
                            label: Text(
                              isGateOpen ? "CLOSE" : "OPEN",
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isGateOpen ? Colors.grey[700] : Colors.green,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onLeaveEarly,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ), 
                        child: const Text("Leave Early", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              if (isActive && isPastTime)
                const Text("Your reservation has ended.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Text("$label: $value", style: const TextStyle(color: Colors.grey), overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Color _getStatusColor(dynamic status) {
    final s = status.toString().toLowerCase();
    if (s.contains('active')) return Colors.green;
    if (s.contains('pending')) return Colors.orange;
    if (s.contains('expire')) return Colors.red;
    if (s.contains('cancel')) return Colors.blueGrey;
    if (s.contains('complete')) return Colors.blue;
    return Colors.grey;
  }
}
