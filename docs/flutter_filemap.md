# Flutter Frontend File Map

Proposed Dart/Flutter client layout for a cross-platform rewrite of `BubblerApp/`.
**Backend stays as-is** (`backend/`, Postgres/pgvector, embeddings, API contracts).

This map is also a **refactor**: fewer files than the SwiftUI client where View/ViewModel
pairs or models were redundant, and clearer boundaries between HTTP, domain models,
and screens.

Related: [`flutter_rewrite_order.md`](flutter_rewrite_order.md), [`api_contracts.md`](api_contracts.md), [`architecture.md`](architecture.md).

---

## Goals vs current iOS tree

| Current Swift pain | Flutter consolidation |
| --- | --- |
| Monolithic `APIClient.swift` (~445 lines) | Domain repositories under `data/repositories/` |
| Five nearly identical settings ViewModels (load profile → form → save/error) | One `AccountController` + thin screens |
| `User` + `PublicUser` as separate types | Single `user.dart` with optional `email` / `isBlocked` |
| `KnownTopics` + `TopicPreferenceList` split | Single `topics.dart` |
| Feed vs Graph as sibling features toggled in one tab | `features/home/` shell + `graph/` + `feed/` |
| `BackendConnection` separate from API | Health check on `ApiClient` |
| SF Symbols / `TopicStyle` inside `TopicPicker` | `shared/theme/topic_style.dart` |
| Flat `Core/` mixing auth, HTTP, and local cache | `core/api`, `core/auth`, `core/storage` |

Approximate target: **~35–40 Dart library files** vs **50 Swift files**, with settings and
networking doing most of the reduction.

---

## Top-level project

```
Bubbler/
├── backend/                         # UNCHANGED
├── scripts/                         # UNCHANGED
├── docs/
├── BubblerApp/                      # Legacy SwiftUI (retire when Flutter ships)
└── bubbler_app/                     # NEW Flutter package (iOS + Android)
    ├── pubspec.yaml
    ├── analysis_options.yaml
    ├── android/
    ├── ios/
    ├── assets/
    │   └── images/                  # logo, app icons source
    ├── test/
    └── lib/
        ├── main.dart
        ├── app/
        ├── core/
        ├── data/
        ├── features/
        └── shared/
```

Package name suggestion: `bubbler_app`. Keep the repo root as the monorepo; do not
move backend into the Flutter tree.

---

## `lib/` tree

```
lib/
├── main.dart                        # WidgetsFlutterBinding, runApp
│
├── app/
│   ├── app.dart                     # MaterialApp / auth gate (ContentView role)
│   ├── router.dart                  # GoRouter (or Navigator 2) tab + stack routes
│   └── theme.dart                   # ColorScheme, text theme, gradient tokens
│
├── core/
│   ├── config.dart                  # base URL, timeouts (APIConfig role)
│   ├── api/
│   │   ├── api_client.dart          # http client, Bearer header, decode, errors
│   │   ├── api_exception.dart       # maps APIClientError cases
│   │   └── endpoints.dart           # path constants (/auth/login, /feed/me, …)
│   ├── auth/
│   │   ├── auth_session.dart        # login/register/signOut/restore (AuthSession)
│   │   └── token_store.dart         # flutter_secure_storage (KeychainStore)
│   └── storage/
│       └── liked_posts_store.dart   # local liked-ID cache
│
├── data/
│   ├── models/
│   │   ├── user.dart                # me + public profile (optional email/isBlocked)
│   │   ├── post.dart
│   │   ├── interaction.dart
│   │   ├── graph.dart               # GraphFeedNode, session, interaction payloads
│   │   ├── preferences.dart         # UserPreferences + strategy weights + update DTO
│   │   ├── search.dart              # SearchResponse
│   │   ├── topics.dart              # known topics + clean/add/remove helpers
│   │   └── blocked_user.dart        # or fold into user.dart if fields stay tiny
│   └── repositories/
│       ├── auth_repository.dart
│       ├── feed_repository.dart     # ranked feed + session seed
│       ├── graph_repository.dart    # /graph/posts/{id}/next
│       ├── post_repository.dart     # create/update/delete + topic mutate
│       ├── search_repository.dart
│       ├── user_repository.dart     # profile, posts, interactions, likes, delete me
│       ├── preferences_repository.dart
│       └── blocks_repository.dart
│
├── features/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   ├── register_screen.dart     # CreateAccount + DOB/age gate
│   │   └── widgets/
│   │       └── auth_form_fields.dart  # shared email/password fields
│   │
│   ├── home/
│   │   ├── home_shell.dart          # MainTabView: Feed | Search | Profile | Settings
│   │   └── feed_tab.dart            # graph ↔ ranked toggle + Create Post entry
│   │
│   ├── graph/                       # product core — highest care
│   │   ├── graph_feed_screen.dart
│   │   ├── graph_feed_controller.dart   # session retries, queue, skip, view-time
│   │   └── widgets/
│   │       ├── bubble_field.dart        # polar layout of ≤4 neighbors
│   │       └── neighbor_bubble.dart
│   │
│   ├── feed/
│   │   ├── ranked_feed_screen.dart
│   │   └── ranked_feed_controller.dart
│   │
│   ├── post/
│   │   ├── create_post_screen.dart
│   │   └── create_post_controller.dart
│   │
│   ├── search/
│   │   ├── search_screen.dart
│   │   └── search_controller.dart
│   │
│   ├── profile/
│   │   ├── my_profile_screen.dart
│   │   ├── user_profile_screen.dart
│   │   ├── bubble_trail.dart
│   │   └── profile_controller.dart  # own + public post lists share one controller API
│   │
│   └── settings/
│       ├── settings_screen.dart     # hub list (legal links, nav to subpages)
│       ├── account/
│       │   ├── profile_info_screen.dart
│       │   ├── email_screen.dart
│       │   ├── password_screen.dart
│       │   ├── delete_account_screen.dart
│       │   └── account_controller.dart  # REPLACES 4 Swift ViewModels
│       ├── preferences/
│       │   ├── preferences_screen.dart
│       │   └── preferences_controller.dart
│       └── blocks/
│           ├── blocked_users_screen.dart
│           └── blocks_controller.dart
│
└── shared/
    ├── widgets/
    │   ├── bubbler_logo.dart
    │   ├── post_card.dart           # like/skip/edit/delete/topic prefs
    │   ├── topic_picker.dart
    │   ├── preference_slider.dart
    │   ├── preference_topics_editor.dart
    │   ├── status_banner.dart       # graph/feed error & status chips
    │   └── async_body.dart          # loading / empty / error shell
    └── theme/
        └── topic_style.dart         # topic colors + icon keys (no SF Symbols)
```

State management is intentionally not prescribed in filenames. Controllers above map to
Swift `*ViewModel` types; implement with whatever the project standardizes on
(e.g. Riverpod `Notifier`, `ChangeNotifier`, or Cubit)—keep **one pattern**.

---

## Swift → Dart mapping

| Swift (today) | Flutter (proposed) |
| --- | --- |
| `App/BubblerAppApp.swift` | `main.dart` + `app/app.dart` |
| `Navigation/ContentView.swift` | auth gate inside `app/app.dart` / router redirect |
| `Navigation/MainTabView.swift` | `features/home/home_shell.dart` + `feed_tab.dart` |
| `Core/APIClient.swift` | `core/api/*` + `data/repositories/*` |
| `Core/AuthSession.swift` | `core/auth/auth_session.dart` |
| `Core/KeychainStore.swift` | `core/auth/token_store.dart` |
| `Core/BackendConnection.swift` | `ApiClient.health()` (no dedicated file) |
| `Core/LikedPostsStore.swift` | `core/storage/liked_posts_store.dart` |
| `Models/User.swift` + `PublicUser.swift` | `data/models/user.dart` |
| `Models/Post.swift` | `data/models/post.dart` |
| `Models/Interaction.swift` | `data/models/interaction.dart` |
| `Models/GraphFeedNode.swift` | `data/models/graph.dart` |
| `Models/UserPreferences.swift` | `data/models/preferences.dart` |
| `Models/SearchResponse.swift` | `data/models/search.dart` |
| `Models/KnownTopics.swift` + `TopicPreferenceList.swift` | `data/models/topics.dart` |
| `Models/BlockedUser.swift` | `data/models/blocked_user.dart` |
| `Components/*` | `shared/widgets/*` (+ `topic_style.dart`) |
| `Features/Auth/*` | `features/auth/*` |
| `Features/Graph/*` | `features/graph/*` |
| `Features/Feed/*` | `features/feed/*` |
| `Features/Post/*` | `features/post/*` |
| `Features/Search/*` | `features/search/*` |
| `Features/Profile/*` | `features/profile/*` |
| `Features/Settings/SettingsView.swift` | `features/settings/settings_screen.dart` |
| `Email*`, `Password*`, `ProfileInformation*`, `DeleteAccount*` View+VM | `settings/account/*` + **one** `account_controller.dart` |
| `PreferencesSettings*` | `settings/preferences/*` |
| `Blocked*` | `settings/blocks/*` |

---

## Consolidation notes (intentional)

### 1. Split the API client; keep transport thin

Swift packs every route into one enum. Flutter should keep a small `ApiClient`
(headers, JSON decode, form-urlencoded login, error body parsing) and put verbs in
repositories that mirror backend domains (`auth`, `feed`, `graph`, `user`, …).
That matches [`api_contracts.md`](api_contracts.md) and avoids another 400-line god file.

### 2. One account controller for settings forms

`EmailSettingsViewModel`, `PasswordSecurityViewModel`, `ProfileInformationViewModel`,
and `DeleteAccountViewModel` share load-profile / busy / error / success patterns.
Fold orchestration into `account_controller.dart`; keep four small screens for UX
clarity. Prefer shared form widgets over four copy-pasted validation blocks.

### 3. Unify user models

`User` (email) and `PublicUser` (`is_blocked`, no email) become one type with optional
fields, or a sealed/me-vs-public split in the same file. Avoid two Codable shapes that
drift.

### 4. Topics in one place

`KnownTopics.resolve` and `TopicPreferenceList.cleaned/add/remove` belong together so
preference editors and create-post pickers cannot diverge. Prefer eventually loading
canonical names from the backend; until then keep the curated list in `topics.dart`
and document sync with `backend/app/db/topics.py`.

### 5. Home shell owns feed mode

Graph ↔ ranked toggle lives in `feed_tab.dart`, not duplicated inside both feed
screens. Create Post stays a route from that tab’s app bar (same as today).

### 6. Shared post card stays central

`PostCardView` is the interaction surface for like/skip/edit/delete/topic prefs across
graph, ranked feed, search, and profile. Keep one `post_card.dart`; do not fork
graph-specific cards unless layout truly diverges.

### 7. Out of scope in this tree

No `features/media/` yet. Schema has a `media` stub, but there is no upload API.
When media ships, add `features/media/` + repository methods only after backend routes
exist—see the media note in [`flutter_rewrite_order.md`](flutter_rewrite_order.md).

---

## Suggested dependencies (client only)

| Package | Role |
| --- | --- |
| `http` or `dio` | REST |
| `flutter_secure_storage` | access token |
| `go_router` (optional) | tabs + nested stacks |
| `intl` | DOB / date display |
| State library of choice | controllers |

Do not pull ML, Postgres, or embedding packages into Flutter—the backend owns those.

---

## Tests layout

```
test/
├── data/models/           # JSON fixture decode (snake_case, DOB day strings)
├── data/repositories/     # mocked HTTP
├── features/graph/        # session retry / queue / diversify state machine
└── shared/widgets/        # optional golden/smoke for post_card, bubble_field
```

Prioritize graph controller tests; that is where Swift behavioral bugs would reappear.

---

## What does not move

| Path | Status |
| --- | --- |
| `backend/` | Keep |
| `scripts/` | Keep |
| `docs/api_contracts.md` | Source of truth for payloads |
| `BubblerApp/` | Legacy until Flutter parity; then archive or delete |
