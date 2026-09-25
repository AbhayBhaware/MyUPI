// lib/models/user_profile.dart
//
// User Profile Domain Model and shared Firestore field constants.
// -----------------------------------------------------------------
// Single source of truth for user profile attributes and Firestore keys.
// Both AuthGate and SetupWizard reference kFieldSetupComplete to eliminate
// any possibility of typo/casing drift.

import 'package:flutter/foundation.dart';

/// Top-level Firestore collection name for merchant profiles.
const String kCollectionUsers = 'users';

/// The exact field name in Firestore marking whether the merchant completed setup.
/// AuthGate and SetupWizard MUST use this exact constant.
const String kFieldSetupComplete = 'setupComplete';

/// Common shop business categories in India.
const List<String> kShopCategories = [
  'Kirana / General Store',
  'Restaurant / Food & Beverages',
  'Clothing & Fashion',
  'Electronics & Mobile',
  'Salon & Personal Care',
  'Medical & Pharmacy',
  'Fruit & Vegetable Vendor',
  'Hardware & Electrical',
  'Stationery & Books',
  'Other',
];

@immutable
class UserProfile {
  final String uid;
  final String ownerName;
  final String shopName;
  final String category;
  final String? categoryOther;
  final String phone;
  final String email;
  final String authMethod; // 'phone' | 'google' | 'email'
  final String upiId; // Merchant's UPI VPA (e.g. 'user@upi') — used for QR code generation
  final bool setupComplete;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.uid,
    required this.ownerName,
    required this.shopName,
    required this.category,
    this.categoryOther,
    required this.phone,
    required this.email,
    required this.authMethod,
    this.upiId = '',
    this.setupComplete = false,
    this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    DateTime? parseDate(dynamic val) {
      if (val is String) return DateTime.tryParse(val);
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return null;
    }

    return UserProfile(
      uid: uid,
      ownerName: (map['ownerName'] as String?) ?? '',
      shopName: (map['shopName'] as String?) ?? 'MyUPI',
      category: (map['category'] as String?) ?? '',
      categoryOther: map['categoryOther'] as String?,
      phone: (map['phone'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      authMethod: (map['authMethod'] as String?) ?? 'phone',
      upiId: (map['upiId'] as String?) ?? '',
      setupComplete: (map[kFieldSetupComplete] as bool?) ?? false,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerName': ownerName,
      'shopName': shopName,
      'category': category,
      if (categoryOther != null && categoryOther!.isNotEmpty)
        'categoryOther': categoryOther,
      'phone': phone,
      'email': email,
      'authMethod': authMethod,
      if (upiId.isNotEmpty) 'upiId': upiId,
      kFieldSetupComplete: setupComplete,
      'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? uid,
    String? ownerName,
    String? shopName,
    String? category,
    String? categoryOther,
    String? phone,
    String? email,
    String? authMethod,
    String? upiId,
    bool? setupComplete,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      ownerName: ownerName ?? this.ownerName,
      shopName: shopName ?? this.shopName,
      category: category ?? this.category,
      categoryOther: categoryOther ?? this.categoryOther,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      authMethod: authMethod ?? this.authMethod,
      upiId: upiId ?? this.upiId,
      setupComplete: setupComplete ?? this.setupComplete,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          setupComplete == other.setupComplete &&
          upiId == other.upiId &&
          shopName == other.shopName &&
          ownerName == other.ownerName;

  @override
  int get hashCode => uid.hashCode ^ setupComplete.hashCode;
}
