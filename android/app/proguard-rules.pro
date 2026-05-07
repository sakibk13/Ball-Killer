# Flutter Proguard Rules
-ignorewarnings
-dontobfuscate
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Play Core rules (fixes the missing class errors)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# General Android/Google rules
-dontwarn com.google.android.gms.**
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-keep class com.google.firebase.** { *; }
