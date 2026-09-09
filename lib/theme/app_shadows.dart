// lib/theme/app_shadows.dart
//
// Subtle, non-muddy elevation shadows for a clean fintech feel.

import 'package:flutter/material.dart';

abstract class AppShadows {
  /// Subtle card elevation for standard surface cards
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color.fromRGBO(17, 24, 39, 0.04),
      offset: Offset(0, 2),
      blurRadius: 8,
      spreadRadius: 0,
    ),
  ];

  /// Elevated shadow for floating banners, primary buttons, or bottom bars
  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color.fromRGBO(17, 24, 39, 0.08),
      offset: Offset(0, 4),
      blurRadius: 16,
      spreadRadius: 0,
    ),
  ];

  /// Soft blue glow for the primary hero card and CTA buttons
  static const List<BoxShadow> primaryGlow = [
    BoxShadow(
      color: Color.fromRGBO(21, 101, 216, 0.25),
      offset: Offset(0, 6),
      blurRadius: 18,
      spreadRadius: 0,
    ),
  ];

  /// Emerald glow for live payment success banner
  static const List<BoxShadow> successGlow = [
    BoxShadow(
      color: Color.fromRGBO(22, 163, 74, 0.25),
      offset: Offset(0, 6),
      blurRadius: 18,
      spreadRadius: 0,
    ),
  ];
}
