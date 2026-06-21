import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

/// CarLoader - A premium, animated loading widget.
/// 
/// Displays a car moving back and forth on a track with engine vibration
/// and a pulsating message text. Used during data fetching or transitions.
class CarLoader extends StatelessWidget {
  /// The message to display under the animated car.
  final String message;

  const CarLoader({super.key, this.message = "Finding your parking..."});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // --- Animation Area ---
          Stack(
            alignment: Alignment.center,
            children: [
              // 1. Track/Road Line
              // A subtle gradient line representing the road surface.
              Container(
                width: 200,
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppTheme.primaryLight.withOpacity(0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              
              // 2. Moving Car Icon
              // An icon that moves horizontally, vibrates, and scales slightly.
              const Icon(
                Icons.directions_car_rounded,
                size: 50,
                color: AppTheme.primaryLight,
              )
              .animate(onPlay: (controller) => controller.repeat()) // Loop the entire sequence
              .moveX(
                begin: -80, 
                end: 80, 
                duration: 1.5.seconds, 
                curve: Curves.easeInOutQuart
              )
              .then() // Reverse the movement
              .moveX(
                begin: 80, 
                end: -80, 
                duration: 1.5.seconds, 
                curve: Curves.easeInOutQuart
              )
              .shake(hz: 8) // Simulate engine vibration
              .scale(
                begin: const Offset(1.0, 1.0), 
                end: const Offset(1.1, 0.9), 
                duration: 200.ms, 
                curve: Curves.bounceIn
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // --- Message Text ---
          // Displays the provided message with a fade-in/out pulse effect.
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
              letterSpacing: 1.2,
            ),
          )
          .animate(onPlay: (controller) => controller.repeat())
          .fadeIn(duration: 800.ms)
          .then()
          .fadeOut(duration: 800.ms),
        ],
      ),
    );
  }
}

