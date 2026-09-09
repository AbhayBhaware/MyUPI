// lib/theme/app_radius.dart
//
// Corner radii constants for restrained, elegant card and element edges.

import 'package:flutter/material.dart';

abstract class AppRadius {
  static const double sm   = 8.0;
  static const double md   = 12.0;
  static const double lg   = 16.0;
  static const double xl   = 20.0;
  static const double xxl  = 24.0;
  static const double pill = 999.0;

  static const BorderRadius smRadius   = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdRadius   = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgRadius   = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlRadius   = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius xxlRadius  = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius pillRadius = BorderRadius.all(Radius.circular(pill));
}
