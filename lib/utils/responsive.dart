import 'package:flutter/material.dart';

/// Responsive layout helpers for tablet and desktop support
class Responsive {
  /// Check if current device is a tablet (width > 600dp)
  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width > 600;
  }

  /// Check if current device is desktop (width > 1024dp)
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width > 1024;
  }

  /// Get maximum content width for current device
  /// - Phone: full width
  /// - Tablet: 800px
  /// - Desktop: 1200px
  static double maxContentWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1024) return 1200; // Desktop
    if (width > 600) return 800; // Tablet
    return double.infinity; // Phone
  }

  /// Wrap content with max-width constraint for tablets/desktop
  static Widget constrainWidth(BuildContext context, Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth(context)),
        child: child,
      ),
    );
  }
}

