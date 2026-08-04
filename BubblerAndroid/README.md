# Bubbler Android

Kotlin + Jetpack Compose client for Bubbler. Parallel to `BubblerApp/` (SwiftUI);
shares the same FastAPI backend. Port plan: [`docs/android_rewrite_order.md`](../docs/android_rewrite_order.md).

## Requirements

- JDK **17** (Android Studio's bundled JBR may be newer; point `JAVA_HOME` at 17)
- Android SDK with API 36
- Local backend on port 8000 (`./scripts/start_backend.sh` from repo root)

```bash
export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
```

## Base URL

Configured in `app/src/main/java/com/bubbler/android/core/config/ApiConfig.kt`.

| Environment | `ApiConfig.BASE_URL` |
| --- | --- |
| Emulator (debug) | `http://10.0.2.2:8000` (default) |
| Physical device (debug) | Your machine's LAN IP, e.g. `http://192.168.1.20:8000` |
| Release / production | HTTPS origin only (do not ship emulator/LAN HTTP) |

Cleartext HTTP is allowed **only in debug** builds via
`app/src/debug/res/xml/network_security_config.xml`. Release uses
`app/src/main/res/xml/network_security_config.xml` (`cleartextTrafficPermitted="false"`)
and R8 minify/shrink with `app/proguard-rules.pro`.

## Run

```bash
cd BubblerAndroid
./gradlew :app:assembleDebug
./gradlew :app:installDebug
./gradlew :app:testDebugUnitTest
```

Or open `BubblerAndroid/` in Android Studio and run the `app` configuration on an
emulator. With the backend up, the login screen shows backend connectivity from
`GET /health`, then the full auth → home → graph/feed flow.

Release assemble (HTTPS base URL required for a usable binary):

```bash
./gradlew :app:assembleRelease
```

## Play Data Safety

Before Play upload, complete the Data Safety form from the same collection inventory
used for Apple App Privacy ([`docs/privacy_legal.md`](../docs/privacy_legal.md) §18):
account info, user content, interactions / view-time, and blocks. See roadmap **L5a**.

## E2E parity

Manual checklist vs iOS on a seeded backend is in Phase 8 of
[`docs/android_rewrite_order.md`](../docs/android_rewrite_order.md).
