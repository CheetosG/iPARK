import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../main.dart';

class AppBackground extends StatelessWidget {
  final Widget child;
  final bool showGrid;
  final bool showGlow;

  const AppBackground({
    super.key,
    required this.child,
    this.showGrid = true,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    // Use a try-catch and null-safety for extreme startup robustness
    late bool isDark;
    try {
      final appState = context.findAncestorStateOfType<IparkAppState>();
      final themeMode = appState?.themeMode ?? ThemeMode.system;
      if (themeMode == ThemeMode.system) {
        isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
      } else {
        isDark = themeMode == ThemeMode.dark;
      }
    } catch (_) {
      isDark = false; // Fallback to light mode on absolute first frame if needed
    }
    final Color bgColor = isDark ? AppTheme.bgDark : AppTheme.bgLight;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          // 1. Base Scaffold Background (Smooth transition)
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              color: bgColor,
            ),
          ),

          // 2. High-Performance Dual-Layer Visuals
          // Cross-fading two static layers.
          
          // LIGHT MODE Visuals
          IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              opacity: isDark ? 0.0 : 1.0,
              child: _buildVisualLayer(isDark: false),
            ),
          ),

          // DARK MODE Visuals
          IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              opacity: isDark ? 1.0 : 0.0,
              child: _buildVisualLayer(isDark: true),
            ),
          ),

          // 4. The Content
          child,
        ],
      ),
    );
  }

  Widget _buildVisualLayer({required bool isDark}) {
    return RepaintBoundary(
      child: Stack(
        children: [
          if (showGlow) ...[
            // Optimized Glows using RadialGradient (Faster than BoxShadow)
            Positioned(
              top: -150,
              right: -150,
              child: _buildGlowGradient(
                AppTheme.primaryLight.withOpacity(isDark ? 0.15 : 0.1),
                400,
              ),
            ),
            Positioned(
              bottom: -100,
              left: -100,
              child: _buildGlowGradient(
                AppTheme.primaryLight.withOpacity(isDark ? 0.1 : 0.06),
                350,
              ),
            ),
          ],
          if (showGrid)
            Positioned.fill(
              child: CustomPaint(
                painter: GridPainter(
                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                  spacing: 30.0, // Increased spacing for fewer points
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// RadialGradient is much cheaper to render for theme transitions than BoxShadow blur.
  Widget _buildGlowGradient(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            color,
            color.withOpacity(0.0),
          ],
          stops: const [0.0, 0.8], // Sharp falloff at 80% to mimic large blur
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  final Color color;
  final double spacing;
  GridPainter({required this.color, this.spacing = 30.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..isAntiAlias = false; // Faster on old phones

    // Batch draw dots as points if possible, but drawCircle is standard.
    // For extreme performance, we'll draw simple points.
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.7, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) => color != oldDelegate.color;
}
