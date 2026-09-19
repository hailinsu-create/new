-keepattributes Signature
-keepattributes *Annotation*
-keepattributes JavascriptInterface

# Activities/services are kept via the manifest. Do not keep the whole app package:
# shrinking should drop unused Kotlin helpers. Keep the Live2D JS bridge and billing.

-keepclassmembers class com.pangchuang.app.Live2DAvatarView$Bridge {
    @android.webkit.JavascriptInterface <methods>;
}

-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**

-keepclassmembers class kotlinx.coroutines.** {
    volatile <fields>;
}

-keep class com.android.vending.billing.** { *; }
-keep class com.android.billingclient.api.** { *; }
