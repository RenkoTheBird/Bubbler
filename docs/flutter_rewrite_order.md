# Flutter Frontend Rewrite Order

Ordered plan for rewriting `BubblerApp/` into the Flutter tree described in
[`flutter_filemap.md`](flutter_filemap.md). Backend remains unchanged; implement
against existing routes in [`api_contracts.md`](api_contracts.md) and graph client
behavior in [`architecture.md`](architecture.md).

Each phase lists **target Dart files** (create in this order within the phase) and
the **Swift sources** they replace. Finish a phase’s vertical slice before starting
the next UI surface—auth must work before graph, graph before polishing settings.

---

## Phase 0 — Project skeleton

**Goal:** Runnable empty app on iOS and Android with theme and config only.

| Order | Create | Replaces / notes |
| --- | --- | --- |
| 0.1 | `bubbler_app/pubspec.yaml`, `analysis_options.yaml` | New package |
| 0.2 | `lib/main.dart` | `App/BubblerAppApp.swift` |
| 0.3 | `lib/app/theme.dart` | Implicit SwiftUI styling / assets accents |
| 0.4 | `lib/app/app.dart` | Shell `MaterialApp`; placeholder home |
| 0.5 | `lib/core/config.dart` | `APIConfig` in `APIClient.swift` |
| 0.6 | `assets/` + platform icon stubs | `Assets.xcassets` |

**Exit:** `flutter run` on a simulator/emulator shows a branded placeholder.

---

## Phase 1 — Networking + auth foundation

**Goal:** Login/register, secure token persistence, session restore. No main tabs yet.

| Order | Create | Replaces |
| --- | --- | --- |
| 1.1 | `core/api/api_exception.dart` | `APIClientError` |
| 1.2 | `core/api/endpoints.dart` | Hard-coded paths in `APIClient` |
| 1.3 | `core/api/api_client.dart` | Transport half of `APIClient` (headers, JSON, form body, `/health`) |
| 1.4 | `core/auth/token_store.dart` | `KeychainStore.swift` |
| 1.5 | `data/models/user.dart` | `User.swift` + `PublicUser.swift` |
| 1.6 | `data/repositories/auth_repository.dart` | `login` / `register` on `APIClient` |
| 1.7 | `core/auth/auth_session.dart` | `AuthSession.swift` |
| 1.8 | `features/auth/widgets/auth_form_fields.dart` | Shared bits of Login/CreateAccount |
| 1.9 | `features/auth/login_screen.dart` | `LoginView.swift` |
| 1.10 | `features/auth/register_screen.dart` | `CreateAccountView.swift` (DOB day string + age gate) |
| 1.11 | Auth redirect in `app/app.dart` / `app/router.dart` | `ContentView.swift` |

**Watch-outs:** OAuth2 password form uses `username` = email; DOB is a calendar date,
not UTC instant. Fold former `BackendConnection` into `ApiClient.health()`—no separate
file.

**Exit:** Register → login → kill app → cold start still authenticated; sign-out clears
secure storage.

---

## Phase 2 — Domain models + remaining repositories

**Goal:** Full HTTP surface available to UI before building screens.

| Order | Create | Replaces |
| --- | --- | --- |
| 2.1 | `data/models/post.dart` | `Post.swift` |
| 2.2 | `data/models/interaction.dart` | `Interaction.swift` |
| 2.3 | `data/models/graph.dart` | `GraphFeedNode.swift` (+ session/payload types) |
| 2.4 | `data/models/preferences.dart` | `UserPreferences.swift` |
| 2.5 | `data/models/search.dart` | `SearchResponse.swift` |
| 2.6 | `data/models/topics.dart` | `KnownTopics.swift` + `TopicPreferenceList.swift` |
| 2.7 | `data/models/blocked_user.dart` | `BlockedUser.swift` |
| 2.8 | `data/repositories/feed_repository.dart` | `getFeed`, `getSessionFeed` |
| 2.9 | `data/repositories/graph_repository.dart` | `getNextGraphPosts` |
| 2.10 | `data/repositories/post_repository.dart` | create/update/delete/topic mutations |
| 2.11 | `data/repositories/search_repository.dart` | `search` |
| 2.12 | `data/repositories/user_repository.dart` | profile, posts, interactions, likes, delete account |
| 2.13 | `data/repositories/preferences_repository.dart` | get/update preferences |
| 2.14 | `data/repositories/blocks_repository.dart` | list/block/unblock |
| 2.15 | `core/storage/liked_posts_store.dart` | `LikedPostsStore.swift` |

**Exit:** Fixture/unit tests decode representative JSON for each model; repositories
compile against `ApiClient`. Prefer model tests here—graph UI comes next.

---

## Phase 3 — Shared UI primitives

**Goal:** Reusable widgets before feature screens (avoids forking post cards).

| Order | Create | Replaces |
| --- | --- | --- |
| 3.1 | `shared/theme/topic_style.dart` | `TopicStyle` inside `TopicPicker.swift` |
| 3.2 | `shared/widgets/bubbler_logo.dart` | `BubblerLogoView.swift` |
| 3.3 | `shared/widgets/topic_picker.dart` | `TopicPicker.swift` |
| 3.4 | `shared/widgets/preference_slider.dart` | `PreferenceSliderRow.swift` |
| 3.5 | `shared/widgets/preference_topics_editor.dart` | `PreferenceTopicsEditor.swift` |
| 3.6 | `shared/widgets/status_banner.dart` | Inline banners in `GraphFeedView` |
| 3.7 | `shared/widgets/async_body.dart` | Repeated loading/empty/error cards |
| 3.8 | `shared/widgets/post_card.dart` | `PostCardView.swift` |

Wire `post_card` to repositories for like/skip/edit/delete only as far as needed for
compile; full interaction paths land with graph/feed.

**Exit:** Widgetbook or a debug gallery page can show logo, topic picker, and a sample
post card.

---

## Phase 4 — Graph feed (product core)

**Goal:** Parity with session walk, ≤4 bubbles, skip, diversify, interactions.

| Order | Create | Replaces |
| --- | --- | --- |
| 4.1 | `features/graph/widgets/neighbor_bubble.dart` | `GraphNeighborBubble` |
| 4.2 | `features/graph/widgets/bubble_field.dart` | Polar layout / `bubbleAngle` in `GraphFeedView` |
| 4.3 | `features/graph/graph_feed_controller.dart` | `GraphFeedViewModel.swift` (**hardest logic**) |
| 4.4 | `features/graph/graph_feed_screen.dart` | `GraphFeedView.swift` |
| 4.5 | Tests under `test/features/graph/` | Documented retry / queue / diversify rules |

**Must match architecture:** up to three session retries; force diversify after first
failure; session queue fallback when a node has no neighbors; view-time on advance;
client-side preferred/blacklist flag refresh on choices.

**Exit:** Manual walk against seeded backend matches Swift behavior for explore, select,
skip, empty-neighbor escape, and preference chips on `PostCard`.

---

## Phase 5 — Home shell + ranked feed + create post

**Goal:** Main navigation and the non-graph discovery path.

| Order | Create | Replaces |
| --- | --- | --- |
| 5.1 | `app/router.dart` (if not done in Phase 1) | Navigation stacks |
| 5.2 | `features/home/home_shell.dart` | `MainTabView.swift` tabs |
| 5.3 | `features/home/feed_tab.dart` | Graph ↔ ranked toggle + Create Post toolbar |
| 5.4 | `features/feed/ranked_feed_controller.dart` | `FeedViewModel.swift` |
| 5.5 | `features/feed/ranked_feed_screen.dart` | `FeedView.swift` |
| 5.6 | `features/post/create_post_controller.dart` | `CreatePostViewModel.swift` |
| 5.7 | `features/post/create_post_screen.dart` | `CreatePostView.swift` |

**Exit:** Tab bar works; toggle switches graph/ranked; create post appears in feed/graph
after refresh.

---

## Phase 6 — Search + profile

**Goal:** Discovery and identity surfaces.

| Order | Create | Replaces |
| --- | --- | --- |
| 6.1 | `features/search/search_controller.dart` | `SearchViewModel.swift` |
| 6.2 | `features/search/search_screen.dart` | `SearchView.swift` |
| 6.3 | `features/profile/profile_controller.dart` | `ProfileViewModel.swift` (+ public fetch) |
| 6.4 | `features/profile/bubble_trail.dart` | `BubbleTrailView.swift` |
| 6.5 | `features/profile/my_profile_screen.dart` | `ProfileView.swift` |
| 6.6 | `features/profile/user_profile_screen.dart` | `UserProfileView.swift` |

**Exit:** Hybrid search returns exact + related; own profile shows posts + trail;
public profile + block entry points work with auth.

---

## Phase 7 — Settings

**Goal:** Account, recommendation prefs, blocks. Uses consolidated account controller
from the file map.

| Order | Create | Replaces |
| --- | --- | --- |
| 7.1 | `features/settings/settings_screen.dart` | `SettingsView.swift` |
| 7.2 | `features/settings/account/account_controller.dart` | Email + Password + ProfileInfo + DeleteAccount **ViewModels** |
| 7.3 | `features/settings/account/profile_info_screen.dart` | `ProfileInformationView.swift` |
| 7.4 | `features/settings/account/email_screen.dart` | `EmailSettingsView.swift` |
| 7.5 | `features/settings/account/password_screen.dart` | `PasswordSecurityView.swift` |
| 7.6 | `features/settings/account/delete_account_screen.dart` | `DeleteAccountView.swift` |
| 7.7 | `features/settings/preferences/preferences_controller.dart` | `PreferencesSettingsViewModel.swift` |
| 7.8 | `features/settings/preferences/preferences_screen.dart` | `PreferencesSettingsView.swift` |
| 7.9 | `features/settings/blocks/blocks_controller.dart` | `BlockedViewModel.swift` |
| 7.10 | `features/settings/blocks/blocked_users_screen.dart` | `BlockedView.swift` |

Normalize strategy weights the same way as iOS before `PUT` preferences.

**Exit:** Full settings parity; delete account signs out; blocks list round-trips.

---

## Phase 8 — Hardening + retire Swift

| Order | Work |
| --- | --- |
| 8.1 | End-to-end checklist vs Swift on same backend seed |
| 8.2 | Android cleartext/debug config for local API (ATS equivalent) |
| 8.3 | App Store / Play Data Safety notes for the Flutter binary |
| 8.4 | Archive or remove `BubblerApp/` when Flutter is canonical |

Launch/legal items in [`roadmap.md`](roadmap.md) (report flow, privacy labels, etc.)
remain product work on top of this client—not a substitute for rewrite phases.

---

## Summary sequence

```text
0 Skeleton
1 Auth + secure storage + ApiClient
2 Models + repositories + liked-posts store
3 Shared widgets (esp. PostCard, topic style)
4 Graph controller + bubble UI          ← highest risk
5 Home shell + ranked feed + create post
6 Search + profile
7 Settings (account consolidated, prefs, blocks)
8 Hardening + retire SwiftUI app
```

---

## Media and the rewrite calculus

**Media is the first feature that changes the rewrite calculus for Flutter.**

Today’s rewrite is favorable because the client is a thin HTTP/JSON UI: no camera,
photo library, uploads, or object storage. The `media` table in `schema.sql` is a
stub; there are no upload routes. Phases 0–8 above assume that text-and-graph world.

When roadmap **F6 (media attachments)** ships, the calculus changes:

| Dimension | Text/graph Flutter (now) | With media (later) |
| --- | --- | --- |
| Stack boundary | Client rewrite only | **Full stack**: upload API, storage, CDN/thumbnails, DB wiring |
| Flutter surface | Standard widgets + one `CustomPainter` | `image_picker` / camera, permissions, compression, progress UI |
| Platform compliance | Normal networking + account data | Photo Library / storage entitlements; Play + App Privacy refresh |
| Trust & safety | Report/moderation as today | CSAM hashing, re-DPIA, retention for binaries ([`privacy_legal.md`](privacy_legal.md), [`roadmap.md`](roadmap.md) F6) |
| File map | No `features/media/` | New feature module + repository methods; `PostCard` and create-post gain attachments |
| Risk to timeline | Predictable port of ~7.6k Swift LOC | Upload reliability, large payloads, and store review dominate over “translate SwiftUI” |

**Guidance:** Complete the Flutter port (Phases 0–8) **without** media. Treat media as a
planned cross-platform feature: design backend upload contracts first, then add
`features/media/` and extend `post_card` / create-post in both mobile targets at once.
Do not invent a Flutter-only media path against the unused schema stub—that would
reintroduce platform-specific drag the current rewrite is designed to avoid.

Other post-launch items (follows, bio, graph-local search) stay ordinary API + screen
work and do **not** change the calculus the way media does.
