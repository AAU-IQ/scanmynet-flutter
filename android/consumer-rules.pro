# Keep all Pigeon-generated platform channel classes.
# R8 minification in release builds would otherwise rename or strip these,
# breaking the Dart<->Kotlin codec at runtime.
-keep class com.creativeadvtech.scanmynet_sdk.** { *; }
