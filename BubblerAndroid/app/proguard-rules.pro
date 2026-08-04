# Keep kotlinx.serialization generated serializers under R8/ProGuard.
-keepattributes *Annotation*, InnerClasses, EnclosingMethod, Signature

-dontnote kotlinx.serialization.AnnotationsKt

# kotlinx-serialization-core
-keep,includedescriptorclasses class kotlinx.serialization.** { *; }
-keepclassmembers class kotlinx.serialization.json.** { *** Companion; }

# App @Serializable models and nested serializers ($serializer / Companion).
-if @kotlinx.serialization.Serializable class **
-keepclassmembers class <1> {
    static <1>$Companion Companion;
}
-if @kotlinx.serialization.Serializable class ** {
    static **$* *;
}
-keepclassmembers class <2>$<3> {
    kotlinx.serialization.KSerializer serializer(...);
}
-if @kotlinx.serialization.Serializable class ** {
    public static ** INSTANCE;
}
-keepclassmembers class <1> {
    public static <1> INSTANCE;
    kotlinx.serialization.KSerializer serializer(...);
}

# Keep enum values used as SerialNames.
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# OkHttp / platform bits used reflectively.
-dontwarn okhttp3.internal.platform.**
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**

# Tink (via security-crypto) references optional Error Prone annotations.
-dontwarn com.google.errorprone.annotations.**
