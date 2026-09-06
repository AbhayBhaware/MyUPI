// lib/models/feature_flags.dart
//
// Future Feature Flags Foundation — Milestone 18
// -----------------------------------------------
// Local configuration system to safely decouple active features from future architecture.
//
// Rules:
//   • notificationSoundbox is active (true).
//   • verifiedPayments MUST remain disabled (false) until a licensed Payment Aggregator is integrated.
//   • backendSync MUST remain disabled (false) for the offline MVP.
//   • premiumFeatures MUST remain disabled (false).

class FeatureFlags {
  final bool notificationSoundbox;
  final bool verifiedPayments;
  final bool backendSync;
  final bool premiumFeatures;

  const FeatureFlags({
    this.notificationSoundbox = true,
    this.verifiedPayments = false,
    this.backendSync = false,
    this.premiumFeatures = false,
  });

  factory FeatureFlags.fromMap(Map<dynamic, dynamic> map) {
    return FeatureFlags(
      notificationSoundbox: (map['notificationSoundbox'] as bool?) ?? true,
      verifiedPayments: (map['verifiedPayments'] as bool?) ?? false,
      backendSync: (map['backendSync'] as bool?) ?? false,
      premiumFeatures: (map['premiumFeatures'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notificationSoundbox': notificationSoundbox,
      'verifiedPayments': verifiedPayments,
      'backendSync': backendSync,
      'premiumFeatures': premiumFeatures,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeatureFlags &&
          runtimeType == other.runtimeType &&
          notificationSoundbox == other.notificationSoundbox &&
          verifiedPayments == other.verifiedPayments &&
          backendSync == other.backendSync &&
          premiumFeatures == other.premiumFeatures;

  @override
  int get hashCode =>
      notificationSoundbox.hashCode ^
      verifiedPayments.hashCode ^
      backendSync.hashCode ^
      premiumFeatures.hashCode;
}
