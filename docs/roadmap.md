# Bubbler Roadmap — What to Do Next

Step-by-step plan. Plain language, exact file paths. Updated after auth pipeline changes and re-added refactor items.

---

## Where You Are Today

### Already in place (do not re-build)

| Area | Location | Notes |
|------|----------|-------|
| Env-based DB + JWT config | `backend/config.py` | `DATABASE`, `DB_USER`, `DATABASE_PASSWORD`, `HOST`, `PORT`, `SECRETKEY`, `ALGORITHM`, `TIMEOFFSET` |
| App lifespan + DB pool | `backend/app/startup.py` | asyncpg pool; auth service wired |
| Dependencies | `backend/Pipfile` | FastAPI, asyncpg, bcrypt/passlib, pyjwt, python-multipart, sentence-transformers |
| Route factory pattern | `backend/app/routes/*.py` | `create_auth_router`, `create_feed_router`, `create_user_router` |
| Route imports (fixed) | `feed.py`, `user.py` | Import from `app.services.feed`, `user`, `post`, `interaction` |
| Pydantic schemas | `backend/app/schemas/` | `CreateUser`, `UserProfile`, `Post`, `Interaction`, `Edge` |
| bcrypt + JWT in auth service | `backend/app/services/auth.py` | `hash_password`, `check_password`, `create_access_token`; login/register return JWT |
| OAuth2 login route | `backend/app/routes/auth.py` | `POST /login` uses `OAuth2PasswordRequestForm`; `POST /register` uses `CreateUser` |
| SQL schema reference | `backend/app/db/schema.sql` | users, topics, posts, edges, interactions, user_profiles |
| Feed algorithm | `backend/app/services/feed.py` | Feed, Strategy, Ranking, Preference services; opposite strategy wired |
| Graph expansion | `backend/app/services/graph.py` | DFS over edges |
| Feed DB queries | `backend/app/repositories/feed_repo.py` | similar, opposite, random, posts-by-id, neighbors, session |
| User prefs query | `backend/app/repositories/user_repo.py` | `getPrefs`; `preferred_topics` typo fixed |
| Interaction repo file | `backend/app/repositories/interaction_repo.py` | Class exists |
| Edge builder | `backend/app/repositories/edge_builder_repo.py` | `build_edges_for_post` |
| iOS UI shell | `BubblerApp/BubblerApp/` | Login, create account, feed, profile, settings, bubble detail |
| Seed script skeleton | `scripts/seed_db.py` | Sample posts + embeddings |

### Not done yet (your backlog)

| Area | Status |
|------|--------|

| iOS backend auth (drop Firebase) | ❌ `AuthSession.swift` still uses Firebase |
| iOS ↔ API | ❌ No `APIClient` in `BubblerApp/` |
| Graph HTTP route | ❌ No `routes/graph.py` |
| Graph path UI | ❌ Feed is mock data |
| Algorithm settings (wired) | ❌ Settings UI is placeholders |
| Automated tests / CI | ❌ None |

**Big picture:**  What remains is connecting iOS and building the graph loop.

---

## How to Read This Roadmap

- Phases are ordered. Complete each checkpoint before moving on.
- Everything below is **still to do**. Completed work appears only in the table above.
- Code blocks are examples — match your files as you implement.

## Phase 3 — iOS: Drop Firebase, Use Backend Auth

**Goal:** Login and register hit your FastAPI backend; JWT stored in Keychain.

### Conditions for dropping Firebase

Do **not** remove Firebase until **all** of these pass:

| # | Condition | How to verify |
|---|-----------|---------------|
| 1 | `POST /register` returns `{access_token, token_type}` | curl / Swagger |
| 2 | `POST /login` (form: username=email, password=…) returns token | curl / Swagger |
| 3 | Protected route rejects missing token (401) | curl without header |
| 4 | Protected route accepts valid token (200) | curl with `Bearer` |
| 5 | iOS `AuthSession` calls backend login/register | Network log |
| 6 | Token stored in Keychain (survives restart) | Kill app, reopen |
| 7 | `APIClient` sends `Authorization: Bearer …` | Debug log |
| 8 | Login + create-account flows work on simulator | Manual test |

**Only after 1–8:** remove Firebase.

### Step 3.1 — Add `APIClient` + Keychain helper

**Create:** `BubblerApp/BubblerApp/APIClient.swift`

Login uses form-encoded body (OAuth2), not JSON:

```swift
func login(email: String, password: String) async throws -> AuthResponse {
    var request = URLRequest(url: baseURL.appendingPathComponent("/login"))
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    let body = "username=\(email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? email)&password=\(password.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? password)"
    request.httpBody = body.data(using: .utf8)
    ...
}
```

Register uses JSON matching `CreateUser`:

```swift
struct RegisterBody: Encodable {
    let username: String
    let email: String
    let password: String
}
```

**Create:** `BubblerApp/BubblerApp/KeychainStore.swift` — save/load/delete `access_token`.

Reference pattern: `ios-app/BubblerApp/App/Services/APIClient.swift` (copy ideas, don't maintain two apps).

### Step 3.2 — Rewrite `AuthSession.swift`

**File:** `BubblerApp/BubblerApp/AuthSession.swift`

- Remove `import FirebaseAuth`
- `signIn` → `APIClient.login` → store token in Keychain → set `isSignedIn = true`
- `createAccount` → `APIClient.register` → same
- `signOut` → delete Keychain token
- On init, restore session if Keychain has valid token

**Update:** `BubblerApp/BubblerApp/ContentView.swift` — remove `FirebaseCore`, `AppDelegate`, `FirebaseApp.configure()`.

**Update:** `CreateAccountView.swift` — collect username (backend requires it).

**Delete (after checklist):**

- `BubblerApp/BubblerApp/GoogleService-Info.plist`
- Firebase SPM dependency in Xcode

**Checkpoint:** Register → login → token in Keychain → no Firebase imports.

---

## Phase 4 — Connect iOS to Real Feed Data

**Goal:** `FeedView` shows API posts, not hard-coded cards.

### Step 4.1 — Add models + view model

**Create:** `BubblerApp/BubblerApp/Post.swift`, `FeedViewModel.swift`

```swift
@MainActor
final class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []

    func loadFeed(token: String) async {
        posts = try await APIClient.shared.get("/feed/me", token: token)
    }
}
```

### Step 4.2 — Wire `FeedView.swift`

Replace hard-coded `feedCard(...)` placeholders with `ForEach(viewModel.posts)`. Pass token from `AuthSession`.

**Checkpoint:** Signed-in user sees real post content from the database.

---

## Phase 5 — Graph Path (Core Product)

**Goal:** One current post + tap-to-choose next posts (DAG path).

### Step 5.1 — Graph feed on iOS

**Create:** `BubblerApp/BubblerApp/GraphFeedView.swift`, `GraphFeedViewModel.swift`

Flow: `GET /feed/me/session` → first post → `GET /graph/posts/{id}/next` → show choices → on tap, `POST /users/me/interactions` + load next.

Reuse styling from `BubbleDetail.swift`.

**Update:** `ContentView.swift` — swap to `GraphFeedView` when the loop works.

### Step 5.2 — View time on interactions

Track seconds on each post; send `view_time` with interaction POST.

**Checkpoint:** Tap through 3–4 posts; each step loads new choices.

---

## Phase 6 — User-Controlled Algorithm

**Goal:** Diversity, randomness, topic lists, view-time — per `docs/api_contracts.md`.

### Step 6.1 — Algorithm settings screen

**Create:** `BubblerApp/BubblerApp/AlgorithmSettingsView.swift`

Wire from `SettingsView.swift` “Bubble Sensitivity” row. Load/save via `APIClient` + JWT.

**Checkpoint:** Changing randomness shuffles results; blacklisting a topic removes those posts.

---

## Phase 7 — Testing & CI

**Goal:** Catch regressions automatically — especially auth and import wiring.

Run this **in parallel** with Phases 0–2; add a test each time you fix an endpoint.

### Step 7.1 — Backend tests

**Create:** `backend/tests/` with `conftest.py`, `test_auth.py`, `test_feed.py`.

**File:** `backend/Pipfile` — dev-packages:

```toml
[dev-packages]
pytest = "*"
pytest-asyncio = "*"
httpx = "*"
```

**File:** `backend/tests/test_auth.py`

```python
@pytest.mark.asyncio
async def test_register_returns_access_token(client):
    response = await client.post("/register", json={
        "username": "testuser",
        "email": "test@bubbler.test",
        "password": "secret123",
    })
    assert response.status_code == 200
    body = response.json()
    assert "access_token" in body
    assert body["token_type"] == "bearer"

@pytest.mark.asyncio
async def test_login_form_returns_token(client, registered_user):
    response = await client.post("/login", data={
        "username": "test@bubbler.test",
        "password": "secret123",
    })
    assert response.status_code == 200
    assert "access_token" in response.json()

@pytest.mark.asyncio
async def test_feed_me_requires_token(client):
    assert (await client.get("/feed/me")).status_code == 401
```

Note: login tests must use **form data** (`data=`), not JSON — your route uses `OAuth2PasswordRequestForm`.

Run: `cd backend && pipenv run pytest`

### Step 7.2 — Backend CI

**Create:** `.github/workflows/backend.yml`

- Trigger on `backend/**`, `ml/**`, `scripts/**`
- Postgres service with pgvector
- Apply `backend/app/db/schema.sql` before tests
- Env vars: `SECRETKEY`, `ALGORITHM`, `TIMEOFFSET`, DB vars

### Step 7.3 — iOS tests

**Create:** `BubblerApp/BubblerAppTests/`

| File | Tests |
|------|-------|
| `AuthSessionTests.swift` | Empty email rejected; token stored after login |
| `APIClientTests.swift` | Mock `URLProtocol`; verify `Authorization` header |
| `FeedViewModelTests.swift` | Decode sample feed JSON into `[Post]` |

Register the test target in Xcode (`BubblerApp.xcodeproj`) if not present.

### Step 7.4 — iOS CI

**Create:** `.github/workflows/ios.yml`

- macOS runner
- `xcodebuild test -project BubblerApp/BubblerApp.xcodeproj -scheme BubblerApp`

### Step 7.5 — Gates before each merge

| Gate | Command |
|------|---------|
| Backend tests | `pipenv run pytest` |
| App starts | `uvicorn main:app` — no import errors |
| iOS unit tests | `xcodebuild test ...` |
| Smoke test | Register → login → `/feed/me` |

---

## Phase 8 — Deploy Basics

### Step 8.1 — Docker Compose for local Postgres

**Create:** `docker-compose.yml` with `pgvector/pgvector:pg16`. Document: compose up → apply schema → seed.

### Step 8.2 — Production checklist

- Rotate `SECRETKEY`
- HTTPS only
- CORS restricted to app origin
- Rate-limit `/login` and `/register`
- Supabase RLS policies if using Supabase auth-adjacent tables

---

---

## What to Avoid

1. **Removing Firebase before the 8-condition checklist passes.**
2. **Maintaining `ios-app/`** — copy patterns into `BubblerApp/`, then ignore the old folder.
3. **Sending JSON to `/login`** — it expects form-urlencoded (`username`, `password`).
4. **Skipping tests after auth changes** — login/register are easy to break silently.
5. **Graph visualization UI** — bubbles + path trail in `ProfileView` is enough.

---

## File Checklist

**Create:**

```
backend/app/routes/graph.py
backend/tests/conftest.py
backend/tests/test_auth.py
backend/tests/test_feed.py
.github/workflows/backend.yml
.github/workflows/ios.yml
BubblerApp/BubblerApp/APIClient.swift
BubblerApp/BubblerApp/KeychainStore.swift
BubblerApp/BubblerApp/Post.swift
BubblerApp/BubblerApp/FeedViewModel.swift
BubblerApp/BubblerApp/GraphFeedView.swift
BubblerApp/BubblerApp/GraphFeedViewModel.swift
BubblerApp/BubblerApp/AlgorithmSettingsView.swift
BubblerApp/BubblerAppTests/AuthSessionTests.swift
BubblerApp/BubblerAppTests/APIClientTests.swift
docker-compose.yml
```

**Edit next (highest priority):**

```
BubblerApp/BubblerApp/AuthSession.swift
BubblerApp/BubblerApp/ContentView.swift
BubblerApp/BubblerApp/FeedView.swift
```

**Delete (only after Phase 3 checklist):**

```
BubblerApp/BubblerApp/GoogleService-Info.plist
(Firebase SPM dependency in Xcode)
```

