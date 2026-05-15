# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Hive
-keep class * extends hive.HiveObject { *; }

# Dio
-keep class io.flutter.plugins.** { *; }
-dontwarn com.google.errorprone.annotations.**

# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# Retrofit / Dio annotations
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# JSON serialization
-keep class com.google.gson.** { *; }
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# Keep Dio interceptor classes
-keep class * extends dio.Interceptor { *; }

# Google Play Core
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# General
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Keep all model classes used with Dio
-keep class * implements java.io.Serializable { *; }

# Keep all classes in the app package
-keep class com.opentrack.opentrack.** { *; }
