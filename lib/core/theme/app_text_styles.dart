import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'app_colors.dart';

// Obsidian CRM Typography
// Inter font at Apple-calibrated negative letter-spacing values.
// Standardized on Sizer 2.0 with proper optical scaling.

class AppTextStyles {
  AppTextStyles._();

  static const String? _font = null;

  // Display / Headlines

  /// ~32-34px — Screen titles / Paywall hero
  static final TextStyle headlineXl = TextStyle(
    fontFamily: _font,
    fontSize: 24.sp,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.75,
    color: AppColors.textPrimary,
  );

  /// ~26-28px — Section headings / Pricing
  static final TextStyle headlineLg = TextStyle(
    fontFamily: _font,
    fontSize: 20.sp,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.59,
    color: AppColors.textPrimary,
  );

  /// ~20-22px — Modal sheet titles, tab labels
  static final TextStyle headlineSm = TextStyle(
    fontFamily: _font,
    fontSize: 16.sp,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.34,
    color: AppColors.textPrimary,
  );

  // Titles

  /// ~17-18px — Row names, strong contact titles
  static final TextStyle titleMd = TextStyle(
    fontFamily: _font,
    fontSize: 14.sp,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.27,
    color: AppColors.textPrimary,
  );

  // Body

  /// ~16-17px — Primary body text / Main chat bubble
  static final TextStyle bodyLg = TextStyle(
    fontFamily: _font,
    fontSize: 13.5.sp,
    fontWeight: FontWeight.w400,
    height: 1.35,
    letterSpacing: -0.27,
    color: AppColors.textPrimary,
  );

  /// ~14-15px — Secondary body / Message previews / Notes
  static final TextStyle bodyMd = TextStyle(
    fontFamily: _font,
    fontSize: 12.sp,
    fontWeight: FontWeight.w400,
    height: 1.35,
    letterSpacing: -0.21,
    color: AppColors.textSecondary,
  );

  // Labels / Meta

  /// ~13px — Subtitles, timestamps, metadata
  static final TextStyle labelMd = TextStyle(
    fontFamily: _font,
    fontSize: 10.5.sp,
    fontWeight: FontWeight.w500,
    height: 1.35,
    letterSpacing: -0.08,
    color: AppColors.textSecondary,
  );

  /// ~11-12px — Pill tags, micro status badges, section caps
  static final TextStyle labelSm = TextStyle(
    fontFamily: _font,
    fontSize: 9.5.sp,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.2,
    color: AppColors.textPrimary,
  );

  /// ~15-16px — Numeric data (timestamps, counts, deal values)
  static final TextStyle numericData = TextStyle(
    fontFamily: _font,
    fontSize: 12.5.sp,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: -0.18,
    color: AppColors.textSecondary,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
