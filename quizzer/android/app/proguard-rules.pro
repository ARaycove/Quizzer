-verbose

# AndroidX Lifecycle
-keep class androidx.lifecycle.** { *; }
-keepclassmembernames class androidx.lifecycle.* { *; }
-keepclassmembers class * implements androidx.lifecycle.LifecycleObserver {
    <init>(...);
}
-keepclassmembers class * extends androidx.lifecycle.ViewModel {
    <init>(...);
}
-keepclassmembers class androidx.lifecycle.Lifecycle$State { *; }
-keepclassmembers class androidx.lifecycle.Lifecycle$Event { *; }
-keepclassmembers class * {
    @androidx.lifecycle.OnLifecycleEvent *;
}

# Flutter wrapper & plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

-keep class dev.fluttercommunity.plus.device_info.** { *; }
-keepclassmembernames class dev.fluttercommunity.plus.device_info.** { *; }
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keepclassmembernames class com.mr.flutter.plugin.filepicker.** { *; }
-keep class com.boskokg.flutter_blue_plus.** { *; }
-keepclassmembernames class com.boskokg.flutter_blue_plus.* { *; }
-keep class net.wolverinebeach.flutter_timezone.** { *; }
-keepclassmembernames class net.wolverinebeach.flutter_timezone.* { *; }
-keep class io.flutter.plugins.flutter_plugin_android_lifecycle.** { *; }
-keepclassmembernames class io.flutter.plugins.flutter_plugin_android_lifecycle.** { *; }
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }
-keepclassmembernames class dev.fluttercommunity.plus.packageinfo.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }
-keepclassmembernames class io.flutter.plugins.pathprovider.** { *; }
-keep class com.twwm.share_files_and_screenshot_widgets.** { *; }
-keepclassmembernames class com.twwm.share_files_and_screenshot_widgets.** { *; }
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keepclassmembernames class io.flutter.plugins.sharedpreferences.** { *; }
-keep class pl.ukaszapps.soundpool.** { *; }
-keepclassmembernames class pl.ukaszapps.soundpool.** { *; }
-keep class com.tekartik.sqflite.** { *; }
-keepclassmembernames class com.tekartik.sqflite.** { *; }
-keep class name.avioli.unilinks.** { *; }
-keepclassmembernames class name.avioli.unilinks.** { *; }
-keep class io.flutter.plugins.urllauncher.** { *; }
-keepclassmembernames class io.flutter.plugins.urllauncher.** { *; }
-keep class dev.fluttercommunity.plus.wakelock.** { *; }
-keepclassmembernames class dev.fluttercommunity.plus.wakelock.** { *; }

# Preserve annotation & metadata
-keepattributes Exceptions,InnerClasses,Signature,Deprecated,SourceFile,LineNumberTable,*Annotation*,EnclosingMethod

-keep class * extends com.google.protobuf.** { *; }
-keepclassmembernames class * extends com.google.protobuf.** { *; }

# Play‑Core / Split Install / Deferred Components
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options

# TensorFlow Lite GPU (if used)
-keep class org.tensorflow.lite.gpu.** { *; }
