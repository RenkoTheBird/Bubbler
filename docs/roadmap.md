# Bubbler Roadmap — What to Do Next

Step-by-step plan. Plain language, exact file paths. Updated after the iOS client merge/reorg and backend-auth integration.

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
| iOS client layout | `BubblerApp/BubblerApp/` | Merged into one feature-based client: `App/`, `Navigation/`, `Core/`, `Models/`, `Components/`, `Features/` |
| iOS backend auth | `BubblerApp/BubblerApp/Core/AuthSession.swift` | Login/register call the backend and persist JWT in Keychain |
| iOS API client | `BubblerApp/BubblerApp/Core/APIClient.swift` | Handles auth calls, bearer auth, and JSON/date decoding |
| iOS feed fetch layer | `BubblerApp/BubblerApp/Features/Feed/FeedViewModel.swift` | Fetches `GET /feed/me` with bearer token |
| Seed script skeleton | `scripts/seed_db.py` | Sample posts + embeddings |

### Not done yet (your backlog)

| Area | Status |
|------|--------|

| Feed UI wiring | ❌ `BubblerApp/BubblerApp/Features/Feed/FeedView.swift` still renders hard-coded cards instead of `FeedViewModel.posts` |
| Reusable post card | ❌ `BubblerApp/BubblerApp/Components/PostCardView.swift` does not yet match the current `Post` model |
| Graph HTTP route | ❌ No `backend/app/routes/graph.py` |
| Graph path UI | ❌ No `BubblerApp/BubblerApp/Features/Graph/` flow yet |
| Algorithm settings (wired) | ❌ `BubblerApp/BubblerApp/Features/Settings/SettingsView.swift` is still placeholder UI |
| Automated tests / CI | ❌ None |

**Big picture:** Backend auth and the iOS app merge are in place. What remains is wiring the real feed, then building the graph loop and algorithm controls on top of the new structure.

---

## How to Read This Roadmap

- Phases are ordered. Complete each checkpoint before moving on.
- Everything below is **still to do**. Completed work appears only in the table above.
- Code blocks are examples — match your files as you implement.

## Phase 5 — Graph Path (Core Product)

**Goal:** One current post + tap-to-choose next posts (DAG path).

### Step 5.1 — Graph feed on iOS

**Create:** `BubblerApp/BubblerApp/Features/Graph/GraphFeedView.swift`, `BubblerApp/BubblerApp/Features/Graph/GraphFeedViewModel.swift`

Flow: `GET /feed/me/session` → first post → `GET /graph/posts/{id}/next` → show choices → on tap, `POST /users/me/interactions` + load next.

Reuse styling from `BubblerApp/BubblerApp/Features/Profile/BubbleDetail.swift`.

**Update:** `BubblerApp/BubblerApp/Navigation/ContentView.swift` or `BubblerApp/BubblerApp/Features/Feed/FeedView.swift` to route into `GraphFeedView` when the loop works.

### Step 5.2 — View time on interactions

Track seconds on each post; send `view_time` with interaction POST.

**Checkpoint:** Tap through 3–4 posts; each step loads new choices.

---

## Phase 6 — User-Controlled Algorithm

**Goal:** Diversity, randomness, topic lists, view-time — per `docs/api_contracts.md`.

### Step 6.1 — Algorithm settings screen

**Create:** `BubblerApp/BubblerApp/Features/Settings/AlgorithmSettingsView.swift`

Wire from `BubblerApp/BubblerApp/Features/Settings/SettingsView.swift` via the “Bubble Sensitivity” row. Load/save through `BubblerApp/BubblerApp/Core/APIClient.swift` with JWT auth.

**Checkpoint:** Changing randomness shuffles results; blacklisting a topic removes those posts.

---

## Phase 7 — Testing & CI

**Goal:** Catch regressions automatically — especially auth and import wiring.

Run this **in parallel** with Phases 3–6; add a test each time you fix an endpoint.

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

1. **Leaving stale Firebase or legacy project config behind** after backend auth is already working.
2. **Re-introducing a second iOS client tree** instead of continuing inside `BubblerApp/BubblerApp/`.
3. **Sending JSON to `/login`** — it expects form-urlencoded (`username`, `password`).
4. **Skipping tests after auth changes** — login/register are easy to break silently.
5. **Graph visualization UI** — bubbles + path trail in `ProfileView` is enough.

---

## File Checklist

**Create next:**

```
backend/app/routes/graph.py
backend/tests/conftest.py
backend/tests/test_auth.py
backend/tests/test_feed.py
.github/workflows/backend.yml
.github/workflows/ios.yml
BubblerApp/BubblerApp/Features/Graph/GraphFeedView.swift
BubblerApp/BubblerApp/Features/Graph/GraphFeedViewModel.swift
BubblerApp/BubblerApp/Features/Settings/AlgorithmSettingsView.swift
BubblerApp/BubblerAppTests/AuthSessionTests.swift
BubblerApp/BubblerAppTests/APIClientTests.swift
docker-compose.yml
```

**Edit next (highest priority):**

```
BubblerApp/BubblerApp/Components/PostCardView.swift
BubblerApp/BubblerApp/Features/Feed/FeedView.swift
BubblerApp/BubblerApp/Navigation/ContentView.swift
BubblerApp/BubblerApp/Features/Settings/SettingsView.swift
```

**Audit / delete if still present:**

```
BubblerApp/BubblerApp/GoogleService-Info.plist
(Firebase package references in `BubblerApp/BubblerApp.xcodeproj`)
```

