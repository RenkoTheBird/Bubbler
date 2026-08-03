# Bubbler Android

Kotlin + Jetpack Compose client for Bubbler. Parallel to `BubblerApp/` (SwiftUI);
shares the same FastAPI backend.

## Requirements

- JDK **17** (Android Studio's bundled JBR may be newer; point `JAVA_HOME` at 17)
- Android SDK with API 36
- Local backend on port 8000 (`./scripts/start_backend.sh` from repo root)

```bash
export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
```

## Base URL

| Environment | `ApiConfig.BASE_URL` |
| --- | --- |
| Emulator | `http://10.0.2.2:8000` (default) |
| Physical device | Your machine's LAN IP, e.g. `http://192.168.1.20:8000` |

Cleartext HTTP is allowed **only in debug** builds via
`app/src/debug/res/xml/network_security_config.xml`. Release builds require HTTPS.

## Run

```bash
cd BubblerAndroid
./gradlew :app:assembleDebug
./gradlew :app:installDebug
```

Or open `BubblerAndroid/` in Android Studio and run the `app` configuration on an
emulator. With the backend up, the Phase 0 shell should show **Connected** and the
database status from `GET /health`.
