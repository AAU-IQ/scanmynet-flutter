# Keep all Pigeon-generated platform channel classes.
# R8 minification in release builds would otherwise rename or strip these,
# breaking the Dart<->Kotlin codec at runtime.
-keep class com.creativeadvtech.scanmynet_sdk.** { *; }

# Keep SWIG JNI director callbacks in the native scan modules (traceroute, etc.).
# SWIG generates static SwigDirector_* methods that are called exclusively from
# native code via JNI. R8 cannot detect these call sites through static analysis
# and strips the methods, causing NoSuchMethodError when the JNI module initialises.
-keep class com.synaptictools.** { *; }
