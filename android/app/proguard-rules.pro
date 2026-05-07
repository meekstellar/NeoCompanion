# Flutter / Dart code is shipped as native libs; these rules cover the Java/
# Kotlin glue from plugins so R8 shrink/minify doesn't strip reflective use.

# Flutter engine entry points and plugin registry.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# flutter_local_notifications keeps a Gson serializer; preserve generic
# signatures and the plugin's notification action receiver.
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.dexterous.** { *; }

# flutter_appauth wraps net.openid.appauth which uses reflection for
# JSON-serialised request descriptors.
-keep class net.openid.appauth.** { *; }

# Connectivity / secure storage / sqflite plugins also use reflection.
-keep class androidx.security.crypto.** { *; }
