# Android Frontend File Map

Proposed Kotlin/Jetpack Compose client layout for an Android port of `BubblerApp/`.
**Backend stays as-is** (`backend/`, Postgres/pgvector, embeddings, API contracts).

This map is also a light **refactor** relative to the SwiftUI tree: split the monolithic
HTTP client into domain repositories, consolidate near-identical settings ViewModels,
and keep clear boundaries between transport, models, and screens.

Related: [`android_rewrite_order.md`](android_rewrite_order.md), [`api_contracts.md`](api_contracts.md), [`architecture.md`](architecture.md).

---

## Goals vs current iOS tree

| Current Swift pain | Android consolidation |
| --- | --- |
| Monolithic `APIClient.swift` (~445 lines) | Domain repositories under `data/repository/` |
| Five nearly identical settings ViewModels | One `AccountViewModel` + thin screens |
| `User` + `PublicUser` as separate types | Single `User` with optional `email` / `isBlocked` |
| `KnownTopics` + `TopicPreferenceList` split | Single `Topics` helpers + preference list types |
| Feed vs Graph as sibling features in one tab | `features/home/` shell + `graph/` + `feed/` |
| `BackendConnection` separate from API | Health check on `ApiClient` |
| SF Symbols / `TopicStyle` inside `TopicPicker` | `ui/theme/TopicStyle.kt` |
| Flat `Core/` mixing auth, HTTP, and local cache | `core/network`, `core/auth`, `core/storage` |

Approximate target: **~40–45 Kotlin source files** under `app/src/main/java/`, with
settings and networking doing most of the reduction vs ~50 Swift files.

---

## Top-level monorepo

```
Bubbler/
├── backend/                         # UNCHANGED
├── scripts/                         # UNCHANGED
├── docs/
├── BubblerApp/                      # Existing SwiftUI iOS client (keep)
└── BubblerAndroid/                  # NEW Android app (Kotlin + Compose)
    ├── settings.gradle.kts
    ├── build.gradle.kts             # root / plugins
    ├── gradle.properties
    ├── gradle/wrapper/
    ├── README.md                    # local run (emulator, base URL)
    └── app/
        ├── build.gradle.kts
        ├── proguard-rules.pro
        └── src/
            ├── main/
            │   ├── AndroidManifest.xml
            │   ├── java/com/bubbler/android/
            │   └── res/
            └── test/
                └── java/com/bubbler/android/
```

Module name: `BubblerAndroid`. Application id / namespace: `com.bubbler.android`.
Keep the repo root as the monorepo; do not move backend into the Android tree.

**Stack (recommended defaults):**

| Concern | Choice |
| --- | --- |
| UI | Jetpack Compose + Material 3 |
| Navigation | Navigation Compose |
| Async / state | Kotlin coroutines + `StateFlow` / `ViewModel` |
| HTTP / JSON | Ktor Client or Retrofit + kotlinx.serialization |
| Tokens | EncryptedSharedPreferences or Keystore-backed store |
| DI | Manual constructors first, or Hilt if the team prefers |

Pick one HTTP stack and one DI approach and stick to them. Filenames below do not
depend on that choice.

---

## `com.bubbler.android` package tree

```
com/bubbler/android/
├── BubblerApplication.kt            # Application class (optional DI bootstrap)
├── MainActivity.kt                  # single-activity Compose host
│
├── app/
│   ├── BubblerApp.kt                # root Composable: theme + auth gate (ContentView)
│   ├── navigation/
│   │   ├── BubblerNavHost.kt        # NavHost graphs (auth + main tabs)
│   │   └── Routes.kt                # route constants / typed routes
│   └── theme/
│       ├── Theme.kt                 # MaterialTheme, color / typography tokens
│       ├── Color.kt
│       └── Type.kt
│
├── core/
│   ├── config/
│   │   └── ApiConfig.kt             # base URL, timeouts (APIConfig role)
│   ├── network/
│   │   ├── ApiClient.kt             # HTTP client, Bearer header, decode, errors
│   │   ├── ApiException.kt          # maps APIClientError cases
│   │   └── Endpoints.kt             # path constants (/auth/login, /feed/me, …)
│   ├── auth/
│   │   ├── AuthSession.kt           # login/register/signOut/restore
│   │   └── TokenStore.kt            # encrypted prefs / Keystore (KeychainStore)
│   └── storage/
│       └── LikedPostsStore.kt       # local liked-ID cache
│
├── data/
│   ├── model/
│   │   ├── User.kt                  # me + public profile (optional email/isBlocked)
│   │   ├── Post.kt
│   │   ├── Interaction.kt
│   │   ├── Graph.kt                 # GraphFeedNode, session, interaction payloads
│   │   ├── Preferences.kt           # UserPreferences + strategy weights + update DTO
│   │   ├── Search.kt                # SearchResponse
│   │   ├── Topics.kt                # known topics + clean/add/remove helpers
│   │   └── BlockedUser.kt           # or fold into User.kt if fields stay tiny
│   └── repository/
│       ├── AuthRepository.kt
│       ├── FeedRepository.kt        # ranked feed + session seed
│       ├── GraphRepository.kt       # /graph/posts/{id}/next
│       ├── PostRepository.kt        # create/update/delete + topic mutate
│       ├── SearchRepository.kt
│       ├── UserRepository.kt        # profile, posts, interactions, likes, delete me
│       ├── PreferencesRepository.kt
│       └── BlocksRepository.kt
│
├── features/
│   ├── auth/
│   │   ├── LoginScreen.kt
│   │   ├── CreateAccountScreen.kt   # DOB / age gate
│   │   ├── AuthViewModel.kt         # optional shared login/register state
│   │   └── components/
│   │       └── AuthFormFields.kt    # shared email/password fields
│   │
│   ├── home/
│   │   ├── MainTabScreen.kt         # MainTabView: Feed | Search | Profile | Settings
│   │   └── FeedTabScreen.kt         # graph ↔ ranked toggle + Create Post entry
│   │
│   ├── graph/                       # product core — highest care
│   │   ├── GraphFeedScreen.kt
│   │   ├── GraphFeedViewModel.kt    # session retries, queue, skip, view-time
│   │   └── components/
│   │       ├── BubbleField.kt       # polar layout of ≤4 neighbors
│   │       └── NeighborBubble.kt
│   │
│   ├── feed/
│   │   ├── RankedFeedScreen.kt
│   │   └── RankedFeedViewModel.kt
│   │
│   ├── post/
│   │   ├── CreatePostScreen.kt
│   │   └── CreatePostViewModel.kt
│   │
│   ├── search/
│   │   ├── SearchScreen.kt
│   │   └── SearchViewModel.kt
│   │
│   ├── profile/
│   │   ├── MyProfileScreen.kt
│   │   ├── UserProfileScreen.kt
│   │   ├── BubbleTrail.kt
│   │   └── ProfileViewModel.kt      # own + public post lists share one ViewModel API
│   │
│   └── settings/
│       ├── SettingsScreen.kt        # hub list (legal links, nav to subpages)
│       ├── account/
│       │   ├── ProfileInfoScreen.kt
│       │   ├── EmailSettingsScreen.kt
│       │   ├── PasswordSecurityScreen.kt
│       │   ├── DeleteAccountScreen.kt
│       │   └── AccountViewModel.kt  # REPLACES 4 Swift ViewModels
│       ├── preferences/
│       │   ├── PreferencesScreen.kt
│       │   └── PreferencesViewModel.kt
│       └── blocks/
│           ├── BlockedUsersScreen.kt
│           └── BlocksViewModel.kt
│
└── ui/
    ├── components/
    │   ├── BubblerLogo.kt
    │   ├── PostCard.kt              # like/skip/edit/delete/topic prefs
    │   ├── TopicPicker.kt
    │   ├── PreferenceSliderRow.kt
    │   ├── PreferenceTopicsEditor.kt
    │   ├── StatusBanner.kt          # graph/feed error & status chips
    │   └── AsyncStateCard.kt        # loading / empty / error card
    └── theme/
        └── TopicStyle.kt            # topic colors + Material icon keys
```

**UI convention:** Use Material 3 for system chrome (dialogs, date pickers, snackbars,
tab bar, progress). Keep branded glass / bubble visuals in shared Compose components
under `ui/components/` and `features/graph/components/`.

State management: feature `*ViewModel` types map 1:1 to Swift `*ViewModel` where logic
is non-trivial. Prefer one pattern (`ViewModel` + `StateFlow` + Compose collect).

---

## Swift → Kotlin mapping

| Swift (today) | Android (proposed) |
| --- | --- |
| `App/BubblerAppApp.swift` | `MainActivity.kt` + `app/BubblerApp.kt` |
| `Navigation/ContentView.swift` | auth gate in `BubblerApp.kt` / nav start destination |
| `Navigation/MainTabView.swift` | `features/home/MainTabScreen.kt` + `FeedTabScreen.kt` |
| `Core/APIClient.swift` | `core/network/*` + `data/repository/*` |
| `Core/AuthSession.swift` | `core/auth/AuthSession.kt` |
| `Core/KeychainStore.swift` | `core/auth/TokenStore.kt` |
| `Core/BackendConnection.swift` | `ApiClient.health()` (no dedicated file) |
| `Core/LikedPostsStore.swift` | `core/storage/LikedPostsStore.kt` |
| `Models/User.swift` + `PublicUser.swift` | `data/model/User.kt` |
| `Models/Post.swift` | `data/model/Post.kt` |
| `Models/Interaction.swift` | `data/model/Interaction.kt` |
| `Models/GraphFeedNode.swift` | `data/model/Graph.kt` |
| `Models/UserPreferences.swift` | `data/model/Preferences.kt` |
| `Models/SearchResponse.swift` | `data/model/Search.kt` |
| `Models/KnownTopics.swift` + `TopicPreferenceList.swift` | `data/model/Topics.kt` |
| `Models/BlockedUser.swift` | `data/model/BlockedUser.kt` |
| `Components/*` | `ui/components/*` (+ `TopicStyle.kt`) |
| `Features/Auth/*` | `features/auth/*` |
| `Features/Graph/*` | `features/graph/*` |
| `Features/Feed/*` | `features/feed/*` |
| `Features/Post/*` | `features/post/*` |
| `Features/Search/*` | `features/search/*` |
| `Features/Profile/*` | `features/profile/*` |
| `Features/Settings/SettingsView.swift` | `features/settings/SettingsScreen.kt` |
| `Email*`, `Password*`, `ProfileInformation*`, `DeleteAccount*` View+VM | `settings/account/*` + **one** `AccountViewModel.kt` |
| `PreferencesSettings*` | `settings/preferences/*` |
| `Blocked*` | `settings/blocks/*` |

---

## Consolidation notes (intentional)

### 1. Split the API client; keep transport thin

Swift packs every route into one enum. Android should keep a small `ApiClient`
(headers, JSON decode, form-urlencoded login, error body parsing) and put verbs in
repositories that mirror backend domains (`auth`, `feed`, `graph`, `user`, …).
That matches [`api_contracts.md`](api_contracts.md) and avoids another 400-line god file.

### 2. One account ViewModel for settings forms

`EmailSettingsViewModel`, `PasswordSecurityViewModel`, `ProfileInformationViewModel`,
and `DeleteAccountViewModel` share load-profile / busy / error / save patterns.
Collapse into `AccountViewModel` with screen-specific methods; keep four thin screens.

### 3. Merge redundant models

- `User` + `PublicUser` → one `User` with optional private fields.
- `KnownTopics` + `TopicPreferenceList` → `Topics.kt` helpers + preference types.
- Graph session / node / interaction payloads live in `Graph.kt` next to the walk types.

### 4. Home shell owns the feed-mode toggle

iOS toggles graph ↔ ranked inside `MainTabView`. Mirror that in
`MainTabScreen` / `FeedTabScreen` so graph and ranked stay focused feature modules.

### 5. Graph stays the highest-care module

Bubble layout and session walk logic are the product differentiator. Keep
`GraphFeedViewModel` behavior aligned with iOS and [`architecture.md`](architecture.md)
(retries, diversify, session queue, view-time). UI pieces (`BubbleField`,
`NeighborBubble`) stay under `features/graph/components/`.

---

## Resources (`res/`)

Minimal Android resources alongside Compose:

```
app/src/main/res/
├── values/
│   ├── strings.xml
│   ├── themes.xml                   # splash / system bar bridge if needed
│   └── colors.xml                   # only if referenced from XML
├── drawable/                        # logo vector / launch assets
├── mipmap-*/                        # launcher icons
└── xml/
    └── network_security_config.xml  # cleartext for local debug API (dev only)
```

Prefer Compose theme tokens over XML styles for in-app chrome. Use
`network_security_config` only for debug/local `http://10.0.2.2:8000` (emulator) or
LAN IP; production builds must use HTTPS.

---

## What stays out of this tree

| Item | Where it lives |
| --- | --- |
| FastAPI routes, services, repos | `backend/` |
| DB schema, embeddings, edge builder | `backend/` |
| Seed / smoke scripts | `scripts/` |
| Product / legal / moderation roadmap | `docs/` |
| iOS SwiftUI client | `BubblerApp/` |

The Android app is a **second client** against the same API. Do not fork backend
contracts for Android; if a contract is wrong, fix it once in `backend/` +
[`api_contracts.md`](api_contracts.md).

---

## Media note

Today’s port assumes text-and-graph only (no uploads). When roadmap media ships,
add upload API contracts first, then extend `PostCard` / create-post—not an
Android-only path against the unused `media` schema stub. See
[`android_rewrite_order.md`](android_rewrite_order.md) for sequencing.
