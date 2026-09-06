// lib/models/merchant_profile.dart
//
// Merchant Profile Domain Model — Milestone 18
// ---------------------------------------------
// Stores only minimal, non-sensitive local settings for the soundbox merchant.
//
// Strictly avoids collecting:
//   - Aadhaar
//   - PAN
//   - Bank account details
//   - UPI PIN
//   - Debit/Credit card details
//   - Passwords / Auth secrets
//   - KYC documents

class MerchantProfile {
  final String merchantId;
  final String shopName;
  final String preferredLanguage;
  final String speechSpeed;
  final String announcementFormat;
  final bool soundboxEnabled;
  final bool includeShopName;

  const MerchantProfile({
    required this.merchantId,
    this.shopName = 'MyUPI',
    this.preferredLanguage = 'en-IN',
    this.speechSpeed = 'normal',
    this.announcementFormat = 'A',
    this.soundboxEnabled = true,
    this.includeShopName = false,
  });

  factory MerchantProfile.fromMap(Map<dynamic, dynamic> map) {
    return MerchantProfile(
      merchantId: (map['merchantId'] as String?) ?? '',
      shopName: (map['shopName'] as String?) ?? 'MyUPI',
      preferredLanguage: (map['preferredLanguage'] as String?) ?? 'en-IN',
      speechSpeed: (map['speechSpeed'] as String?) ?? 'normal',
      announcementFormat: (map['announcementFormat'] as String?) ?? 'A',
      soundboxEnabled: (map['soundboxEnabled'] as bool?) ?? true,
      includeShopName: (map['includeShopName'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'merchantId': merchantId,
      'shopName': shopName,
      'preferredLanguage': preferredLanguage,
      'speechSpeed': speechSpeed,
      'announcementFormat': announcementFormat,
      'soundboxEnabled': soundboxEnabled,
      'includeShopName': includeShopName,
    };
  }

  MerchantProfile copyWith({
    String? merchantId,
    String? shopName,
    String? preferredLanguage,
    String? speechSpeed,
    String? announcementFormat,
    bool? soundboxEnabled,
    bool? includeShopName,
  }) {
    return MerchantProfile(
      merchantId: merchantId ?? this.merchantId,
      shopName: shopName ?? this.shopName,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      speechSpeed: speechSpeed ?? this.speechSpeed,
      announcementFormat: announcementFormat ?? this.announcementFormat,
      soundboxEnabled: soundboxEnabled ?? this.soundboxEnabled,
      includeShopName: includeShopName ?? this.includeShopName,
    );
  }
}
