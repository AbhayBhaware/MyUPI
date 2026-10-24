# Flutter Wrapper Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# MyUPI Soundbox Native Architecture
-keep class com.myupi.soundbox.** { *; }
-keepclassmembers class com.myupi.soundbox.** { *; }

# Google Play In-App Purchase & Billing Client
-keep class com.android.billingclient.** { *; }
-keep interface com.android.billingclient.** { *; }

# Firebase Services
-keepattributes *Annotation*
-dontwarn com.google.firebase.**

# Play Core & Flutter Deferred Components
-dontwarn com.google.android.play.core.**

