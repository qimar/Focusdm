import 'package:flutter/material.dart';

// Instagram-Matched Dark Mode
// Colors sampled directly from Instagram's WebView at runtime on device.
// Background: #0C1014, Cards: #212328, Elevated: #25292E, Borders: #2F333A

class AppColors {
  AppColors._();

  // Canvas
  static const Color background = Color(0xFF0C1014); // Instagram body background
  static const Color surface = Color(0xFF212328);    // Instagram card / list-row surface
  static const Color surfaceHigh = Color(0xFF25292E); // Instagram search bar / note pill
  static const Color surfaceBright = Color(0xFF2F333A); // Instagram dialog / bottom-sheet

  // Borders & Dividers
  static const Color border = Color(0xFF2F333A);    // Instagram hairline divider
  static const Color borderBright = Color(0xFF3A3E46); // Modal / overlay borders

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF); // White - headings/names
  static const Color textSecondary = Color(0xFFA8A8A8); // Instagram secondary text
  static const Color textTertiary = Color(0xFF737373); // Instagram tertiary/placeholder

  // Interactive
  static const Color btnPrimary = Color(0xFFFFFFFF); // Solid white button fill
  static const Color btnPrimaryText = Color(
    0xFF000000,
  ); // Black text on white btn
  static const Color chevron = Color(0xFF636366); // Trailing icons

  // Pastel CRM Status Indicators
  // Each has a background (bg) and foreground text (fg) variant.
  // Used for pipeline stage pills in the inbox and CRM drawer.

  // New Inquiry / Lead / Discovery
  static const Color tagSkyBg = Color(0xFF142233);
  static const Color tagSkyFg = Color(0xFF93C5FD);

  // Active / Won / Closed
  static const Color tagEmeraldBg = Color(0xFF16261E);
  static const Color tagEmeraldFg = Color(0xFF86EFAC);

  // Follow Up / Pending / Under Review
  static const Color tagAmberBg = Color(0xFF2D2314);
  static const Color tagAmberFg = Color(0xFFFDE047);

  // Hot / Urgent / Stalled
  static const Color tagRoseBg = Color(0xFF2C1A1D);
  static const Color tagRoseFg = Color(0xFFFDA4AF);

  // Nurturing / Cold / On Hold
  static const Color tagLavenderBg = Color(0xFF231A2F);
  static const Color tagLavenderFg = Color(0xFFD8B4FE);

  // Danger
  static const Color danger = Color(0xFFED4956); // Instagram destructive text
  static const Color dangerBg = Color(0xFF2C1A1D); // Destructive background
}
