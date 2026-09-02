-keepattributes Signature
-keepattributes *Annotation*

-keep class com.pangchuang.app.** { *; }

-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

-keepclassmembers class kotlinx.coroutines.** {
    volatile <fields>;
}

-keep class com.android.vending.billing.** { *; }
-keep class com.android.billingclient.api.** { *; }
