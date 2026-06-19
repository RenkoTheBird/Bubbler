# Bubbler Roadmap — What to Do Next

Step-by-step plan for a **solo developer**. Plain language, exact file paths, updated for the **refactored backend** (post–folder restructure).

---

## Where You Are Today

### Already in place (do not re-build these)

| Area | Location | Notes |
|------|----------|-------|
| Env-based DB config | `backend/config.py` | Loads `DATABASE`, `DB_USER`, `DATABASE_PASSWORD`, `HOST`, `PORT`; builds `db_url` |
| App lifespan + DB pool | `backend/app/startup.py` | asyncpg pool on startup |
| Dependency manifest | `backend/Pipfile` | FastAPI, asyncpg, passlib/bcrypt, pydantic |
| Route factory pattern | `backend/app/routes/*.py` | `create_auth_router`, `create_feed_router`, `create_user_router` |
| Pydantic schemas | `backend/app/schemas/` | `CreateUser`, `UserLogin`, `UserProfile`, `Post`, `Interaction`, `Edge` |
| bcrypt helpers | `backend/app/services/auth.py` | `hash_password`, `check_password` |
| Auth endpoints (shape) | `backend/app/routes/auth.py` | `POST /login`, `POST /register` with request bodies |
| Feed algorithm code | `backend/app/services/feed.py` | `FeedService`, `StrategyService`, `RankingService`, `PreferenceService` |
| Graph expansion | `backend/app/services/graph.py` | DFS over edges |
| Feed DB queries | `backend/app/repositories/feed_repo.py` | Similar/random/posts-by-id/neighbors/session (classmethod + pool) |
| User prefs query | `backend/app/repositories/user_repo.py` | `getPrefs` (merged from old `user_pref_repo`) |
| Edge builder | `backend/app/repositories/edge_builder_repo.py` | `build_edges_for_post` |
| iOS UI shell | `BubblerApp/BubblerApp/` | Login, create account, feed, profile, settings, bubble detail |
| Seed script skeleton | `scripts/seed_db.py` | Sample posts + embeddings |

### Not done yet (your actual backlog)

| Area | Status |
|------|--------|
| All routers registered in `startup.py` | ❌ Only auth is registered today |
| Import paths aligned with new file names | ❌ Routes import `feed_service`, `user_service`, etc. — files are `feed.py`, `user.py` |
| JWT auth | ❌ Not implemented |
| Firebase → backend auth on iOS | ❌ Still on Firebase (`AuthSession.swift`) |
| SQL schema file | ❌ Removed in refactor — no `backend/app/db/schema.sql` |
| `interaction_repo` | ❌ Removed — `InteractionService` has nothing to call |
| Graph HTTP route | ❌ No `routes/graph.py` |
| `getOppositePosts` | ❌ Removed from `feed_repo` |
| iOS ↔ API connection | ❌ No `APIClient` in `BubblerApp/` |
| Graph path UI | ❌ Feed is mock data |
| Algorithm settings (wired) | ❌ Settings UI is placeholders |
| Automated tests / CI | ❌ None |

**Big picture:** The refactor cleaned up folder layout (`routes/`, `services/`, `schemas/`, `startup.py`) but only auth is wired end-to-end. Several pieces from the pre-refactor backend were dropped or left half-migrated. Next priorities: finish wiring, restore missing repos/schema, add JWT, connect iOS, then build the graph loop.

---

## New Backend Layout (read this once)

```
backend/
├── main.py                 # FastAPI app + lifespan import
├── config.py               # Env vars → db_url
├── Pipfile                 # Dependencies
├── app/
│   ├── startup.py          # Pool, service init, router registration
│   ├── routes/
│   │   ├── auth.py         # create_auth_router(auth_service)
│   │   ├── feed.py         # create_feed_router(feed_service)
│   │   └── user.py         # create_user_router(...)
│   ├── services/
│   │   ├── auth.py
│   │   ├── feed.py         # Feed + Strategy + Ranking + Preference
│   │   ├── graph.py
│   │   ├── post.py
│   │   ├── user.py
│   │   └── interaction.py
│   ├── repositories/
│   │   ├── auth_repo.py
│   │   ├── feed_repo.py    # Also handles graph neighbor queries
│   │   ├── post_repo.py
│   │   ├── user_repo.py    # Profile + preferences
│   │   └── edge_builder_repo.py
│   └── schemas/
│       ├── user.py
│       ├── post.py
│       └── edge.py
```

There is no `api/deps.py` anymore — **`startup.py` owns wiring**.

---

## How to Read This Roadmap

- Phases are ordered. Complete each checkpoint before moving on.
- Steps listed here are **not yet done**. Completed work appears only in the summary table above.
- Code blocks are examples — match naming to your files as you implement.

---

## Phase 0 — Finish Refactor Wiring

**Goal:** App starts, all routers register, imports resolve, one feed request returns JSON.

### Step 0.1 — Align service method names with routes

Several services use mixed `camelCase` / `snake_case`. Pick **snake_case** for Python and make routes + services match.

**File:** `backend/app/services/auth.py` — fix login (undefined `id`, wrong hash flow):

```python
async def post_login_info(self, email: str, password: str):
    row = await self.auth_repo.get_user_by_email(email)
    if not row:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    if not check_password(password.encode(), row["password_hash"].encode()):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    return row  # later: wrap in JWT (Phase 1)
```

**File:** `backend/app/repositories/auth_repo.py` — fix column name (`password` → `password_hash`), add lookup by email:

```python
async def get_user_by_email(self, email: str):
    async with self.pool.acquire() as conn:
        return await conn.fetchrow(
            "SELECT id, email, password_hash FROM users WHERE email = $1", email
        )
```

### Step 0.2 — Wire all routers in `startup.py`

**File:** `backend/app/startup.py` — today only auth registers. Extend:

```python
from app.services.feed import FeedService, StrategyService, RankingService, PreferenceService
from app.services.graph import GraphService
from app.services.post import PostService, EmbeddingService
from app.services.user import UserService
from app.services.interaction import InteractionService
from app.routes.feed import create_feed_router
from app.routes.user import create_user_router

# Build services (pass pool into repos — see Step 0.3)
feed_service = FeedService(...)
fastapi.include_router(create_feed_router(feed_service), prefix="/feed", tags=["feed"])
fastapi.include_router(create_user_router(...), prefix="/users", tags=["users"])
```

Store `pool` on `app.state.pool` so services/repos can access it if needed.

### Step 0.3 — Pick one repository pattern

**Problem:** `FeedRepository` uses `@classmethod` + `pool` argument; `FeedService` expects instance repos with methods like `getSimilarPosts`. `GraphService` calls `self.repo.getNeighbors` but repo has `get_neighbors(cls, pool, ...)`.

Choose **instance repos** (cleaner with your service classes):

**File:** `backend/app/repositories/feed_repo.py`

```python
class FeedRepository:
    def __init__(self, pool):
        self.pool = pool

    async def get_similar_posts(self, embedding, limit=4):
        ...

    async def get_neighbors(self, post_id, limit=4):
        ...
```

Update `FeedService` / `StrategyService` / `GraphService` to call the snake_case methods.

**Checkpoint:** `uvicorn main:app --reload` from `backend/`, Swagger at `/docs` shows `/auth`, `/feed`, `/users`. No import errors on startup.

---

## Phase 1 — Auth: bcrypt + JWT (Replace Firebase)

**Goal:** Backend issues JWT on login/register. iOS can authenticate without Firebase.

### Step 1.1 — Add JWT dependencies and config

**File:** `backend/Pipfile` — add:

```toml
python-jose = {extras = ["cryptography"], version = "*"}
```

**File:** `backend/config.py` — add `JWT_SECRET` and `JWT_EXPIRE_MINUTES` to required env vars (or optional with dev default).

**Create:** `backend/app/security/jwt.py`

```python
from datetime import datetime, timedelta, timezone
from jose import jwt
from config import my_env_vars

def create_access_token(user_id: int) -> str:
    payload = {
        "sub": str(user_id),
        "exp": datetime.now(timezone.utc) + timedelta(minutes=my_env_vars.jwt_expire_minutes),
    }
    return jwt.encode(payload, my_env_vars.jwt_secret, algorithm="HS256")
```

**Create:** `backend/.env.example`:

```env
DATABASE=bubbler
DB_USER=bubbler
DATABASE_PASSWORD=changeme
HOST=localhost
PORT=5432
JWT_SECRET=change-me-in-production
JWT_EXPIRE_MINUTES=10080
```

### Step 1.2 — Return JWT from auth endpoints

**File:** `backend/app/services/auth.py`

```python
async def post_login_info(self, email: str, password: str):
    user = await self.auth_repo.get_user_by_email(email)
    # ... verify password ...
    token = create_access_token(user["id"])
    return {"access_token": token, "token_type": "bearer", "user_id": user["id"]}
```

Same pattern for register — create user, return token.

### Step 1.3 — Protect routes with JWT dependency

**Create:** `backend/app/security/deps.py`

```python
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError

security = HTTPBearer()

async def get_current_user_id(credentials: HTTPAuthorizationCredentials = Depends(security)) -> int:
    try:
        payload = jwt.decode(credentials.credentials, my_env_vars.jwt_secret, algorithms=["HS256"])
        return int(payload["sub"])
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")
```

Use on feed/user routes instead of raw `{id}` in URL where appropriate:

```python
@router.get("/me")
async def get_my_feed(user_id: int = Depends(get_current_user_id), ...):
    return await feed_service.get_feed(user_id, "")
```

### Step 1.4 — Conditions for dropping Firebase (iOS)

Do **not** remove Firebase until **all** of these are true:

| # | Condition | How to verify |
|---|-----------|---------------|
| 1 | `POST /login` returns `access_token` | curl or Swagger |
| 2 | `POST /register` creates user + returns token | New email registers successfully |
| 3 | Protected endpoint rejects missing token (401) | curl without `Authorization` header |
| 4 | Protected endpoint accepts valid token (200) | curl with `Bearer <token>` |
| 5 | iOS `AuthSession` calls backend login/register | Breakpoint / log network call |
| 6 | Token stored in Keychain (survives app restart) | Kill app, reopen, still signed in |
| 7 | `APIClient` sends `Authorization: Bearer ...` on every request | Log headers in debug |
| 8 | Login + create-account flows work on device/simulator | Manual test both paths |

**Only after 1–8:** remove Firebase.

### Step 1.5 — Replace Firebase on iOS

**Create:** `BubblerApp/BubblerApp/APIClient.swift`

```swift
final class APIClient {
    static let shared = APIClient()
    private let baseURL = URL(string: "http://127.0.0.1:8000")!

    func post<T: Decodable>(_ path: String, body: Encodable, token: String? = nil) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONEncoder().encode(body)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
```

**Rewrite:** `BubblerApp/BubblerApp/AuthSession.swift` — remove `import FirebaseAuth`; call `/login` and `/register`; store token via Keychain helper.

**Update:** `BubblerApp/BubblerApp/ContentView.swift` — remove `FirebaseCore`, `AppDelegate`, `FirebaseApp.configure()`.

**Delete (after conditions met):**

- `BubblerApp/BubblerApp/GoogleService-Info.plist`
- Firebase package from Xcode (`project.pbxproj` / Swift Package dependencies)

**Checkpoint:** Register → login → token in Keychain → authenticated API call succeeds. No Firebase imports remain.

---

## Phase 2 — Restore Missing Backend Pieces

**Goal:** Database schema exists, seed data loads, interactions and opposite-post strategy work.

These existed before the refactor but are **missing now**.

### Step 2.1 — Recreate `interaction_repo`

**Create:** `backend/app/repositories/interaction_repo.py`

```python
class InteractionRepository:
    def __init__(self, pool):
        self.pool = pool

    async def record(self, user_id: int, post_id: str, type: str, view_time: float = 0):
        ...

    async def get_recent_interactions(self, user_id: int, limit: int = 50):
        ...
```

Wire into `InteractionService` and `startup.py`. Add `POST /interactions` route (new file or extend `user.py`).

### Step 2.2 — Wire edge builder on post create

**File:** `backend/app/services/post.py` — after insert, call `EdgeBuilderRepo.build_edges_for_post`.

Fix `post_repo.py` bugs (`cls.pool` → `self.pool`, import path `backend.app.schemas` → `app.schemas`).

**Checkpoint:** Seed script inserts users + posts + edges. `GET /feed/1` returns ranked posts.

---

## Phase 3 — Connect iOS to Real Data

**Goal:** `FeedView` shows API posts, not hard-coded cards.

### Step 3.1 — Add models + view model

**Create:** `BubblerApp/BubblerApp/Post.swift`, `FeedViewModel.swift`

Load from `/feed/me` (JWT) or `/feed/{id}` during development.

### Step 3.2 — Replace mock cards in `FeedView.swift`

Swap `feedCard(...)` placeholders for `ForEach(viewModel.posts)`.

Keep bubble chips static for now — topic filtering comes in Phase 5.

**Checkpoint:** Signed-in user sees real post content from Postgres.

---

## Phase 4 — Graph Path (Core Product)

**Goal:** One current post + tap-to-choose next posts (DAG path).

### Step 4.1 — Graph route

**Create:** `backend/app/routes/graph.py`

```python
def create_graph_router(pool):
    router = APIRouter()

    @router.get("/posts/{post_id}/next")
    async def get_next_posts(post_id: str, user_id: int = Depends(get_current_user_id)):
        neighbors = await FeedRepository(pool).get_neighbors(post_id, limit=4)
        ids = [n["to_post_id"] for n in neighbors]
        return await FeedRepository(pool).get_posts_by_ids(ids)

    return router
```

Register in `startup.py` with prefix `/graph`.

### Step 4.2 — Graph feed on iOS

**Create:** `BubblerApp/BubblerApp/GraphFeedView.swift`, `GraphFeedViewModel.swift`

Flow: `GET /feed/{id}/session` → first post → `GET /graph/posts/{id}/next` → show choices → on tap, record interaction + load next.

Reuse styling from `BubbleDetail.swift`.

**Update:** `ContentView.swift` — use `GraphFeedView` instead of mock `FeedView` when loop works.

### Step 4.3 — Record interactions + view time

Post to interactions endpoint with `type: "explore"` and `view_time` seconds.

**Checkpoint:** Tap through 3–4 posts in a row; each step loads new choices.

---

## Phase 5 — User-Controlled Algorithm

**Goal:** Diversity, randomness, topic lists, view-time weighting — per `docs/api_contracts.md`.

### Step 5.1 — Preferences API

**File:** `backend/app/routes/user.py` — add:

```python
@router.get("/me/preferences")
async def get_preferences(user_id: int = Depends(get_current_user_id)):
    return await user_repo.get_prefs(user_id)

@router.put("/me/preferences")
async def update_preferences(body: PrefsUpdate, user_id: int = Depends(get_current_user_id)):
    return await user_repo.update_prefs(user_id, body)
```

Add `update_prefs` to `user_repo.py`.

### Step 5.2 — Algorithm settings screen

**Create:** `BubblerApp/BubblerApp/AlgorithmSettingsView.swift`

Wire from `SettingsView.swift` “Bubble Sensitivity” row. Load/save via `APIClient` + JWT.

**Checkpoint:** Changing randomness shuffles results; blacklisting a topic removes those posts.

---

## Phase 6 — Testing & CI

**Goal:** Catch regressions automatically — especially important after the refactor broke import paths once already.

### Step 6.1 — Backend unit + integration tests

**Create:** `backend/tests/` package.

**File:** `backend/Pipfile` — dev-packages:

```toml
[dev-packages]
pytest = "*"
pytest-asyncio = "*"
httpx = "*"
```

**Create:** `backend/tests/conftest.py` — test client with lifespan override or test DB URL.

**Create:** `backend/tests/test_auth.py`

```python
@pytest.mark.asyncio
async def test_register_returns_token(client):
    response = await client.post("/register", json={
        "username": "testuser",
        "email": "test@bubbler.test",
        "password": "secret123",
    })
    assert response.status_code == 200
    assert "access_token" in response.json()

@pytest.mark.asyncio
async def test_protected_route_requires_token(client):
    response = await client.get("/feed/me")
    assert response.status_code == 401
```

**Create:** `backend/tests/test_feed.py` — feed returns list for authenticated user.

**Create:** `backend/tests/test_repositories/test_feed_repo.py` — mock pool or use test DB for `get_similar_posts`, `get_posts_by_ids`.

Run locally:

```bash
cd backend && pipenv run pytest
```

### Step 6.2 — Backend CI pipeline

**Create:** `.github/workflows/backend.yml`

```yaml
name: Backend CI

on:
  push:
    paths: ['backend/**', 'ml/**', 'scripts/**']
  pull_request:
    paths: ['backend/**', 'ml/**', 'scripts/**']

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: pgvector/pgvector:pg16
        env:
          POSTGRES_USER: bubbler
          POSTGRES_PASSWORD: bubbler
          POSTGRES_DB: bubbler
        ports: ['5432:5432']
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - run: pip install pipenv
      - working-directory: backend
        run: |
          pipenv install --dev
          pipenv run pytest
        env:
          DATABASE: bubbler
          DB_USER: bubbler
          DATABASE_PASSWORD: bubbler
          HOST: localhost
          PORT: 5432
          JWT_SECRET: ci-test-secret
```

Add a step to apply `backend/db/schema.sql` before tests once schema exists.

### Step 6.3 — iOS unit tests (component registration)

**Create:** `BubblerApp/BubblerAppTests/` target in Xcode if not present.

**Create:** `BubblerApp/BubblerAppTests/AuthSessionTests.swift`

```swift
import XCTest
@testable import BubblerApp

final class AuthSessionTests: XCTestCase {
    func testLoginRejectsEmptyEmail() async {
        let session = AuthSession()
        await session.signIn(email: "", password: "secret")
        XCTAssertNotNil(session.authError)
    }
}
```

**Create:** `BubblerApp/BubblerAppTests/APIClientTests.swift` — mock `URLProtocol` to verify `Authorization` header is sent when token is set.

**Create:** `BubblerApp/BubblerAppTests/FeedViewModelTests.swift` — decode sample JSON into `[Post]`.

### Step 6.4 — iOS UI tests (optional but valuable)

**Create:** `BubblerApp/BubblerAppUITests/LoginFlowTests.swift`

```swift
func testLoginScreenShowsEmailField() {
    let app = XCUIApplication()
    app.launch()
    XCTAssertTrue(app.textFields["Enter your email"].exists)
}
```

### Step 6.5 — CI for iOS (macOS runner)

**Create:** `.github/workflows/ios.yml`

```yaml
name: iOS CI

on:
  push:
    paths: ['BubblerApp/**']
  pull_request:
    paths: ['BubblerApp/**']

jobs:
  build-and-test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run unit tests
        run: |
          xcodebuild test \
            -project BubblerApp/BubblerApp.xcodeproj \
            -scheme BubblerApp \
            -destination 'platform=iOS Simulator,name=iPhone 16' \
            -only-testing:BubblerAppTests
```

Adjust scheme/simulator name to match your project.

### Step 6.6 — Testing gates (use at every phase)

Before merging any phase:

| Gate | Command |
|------|---------|
| Backend tests green | `pipenv run pytest` |
| App starts | `uvicorn main:app` — no import errors |
| iOS unit tests green | `xcodebuild test ...` |
| Manual smoke | Register → login → feed loads |

**Checkpoint:** PRs run GitHub Actions; failing tests block merge.

---

## Phase 7 — Deploy Basics

**Goal:** Repeatable local dev + path to TestFlight.

### Step 7.1 — Docker Compose for Postgres

**Create:** `docker-compose.yml` at repo root with `pgvector/pgvector:pg16`. Document in README: `docker compose up -d` → apply schema → seed.

### Step 7.2 — Production env checklist

- Rotate `JWT_SECRET`
- HTTPS only
- CORS restricted to your app origin
- Rate-limit `/login` and `/register`

---

## Suggested Timeline (Solo Dev)

| Phase | Focus | Rough time |
|-------|-------|------------|
| 0 | Refactor wiring + imports | 1 weekend |
| 1 | JWT + Firebase drop | 1–2 weekends |
| 2 | Schema + missing repos | 1 weekend |
| 3 | iOS ↔ API | 1 weekend |
| 4 | Graph path | 2–3 weekends |
| 5 | Algorithm settings | 1–2 weekends |
| 6 | Tests + CI | 1–2 weekends |
| 7 | Deploy basics | 1 weekend |

Run Phase 6 **in parallel** once Phase 0 completes — add tests for each new endpoint as you build it.

---

## What to Avoid

1. **Re-creating `deps.py`** unless startup becomes unwieldy — the factory + startup pattern is fine for a solo dev.
2. **Removing Firebase before JWT works** — use the 8-condition checklist in Phase 1.4.
3. **Maintaining `ios-app/`** — copy `APIClient` patterns into `BubblerApp/`, then ignore the old folder.
4. **Skipping tests after a refactor** — import renames will break again; CI pays for itself quickly.
5. **Graph visualization** — bubbles + path trail in `ProfileView` is enough.

---

## File Checklist

**Create:**

```
backend/.env.example
backend/db/schema.sql
backend/app/security/jwt.py
backend/app/security/deps.py
backend/app/repositories/interaction_repo.py
backend/app/routes/graph.py
backend/tests/conftest.py
backend/tests/test_auth.py
backend/tests/test_feed.py
.github/workflows/backend.yml
.github/workflows/ios.yml
BubblerApp/BubblerApp/APIClient.swift
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
backend/app/startup.py
backend/app/routes/auth.py
backend/app/routes/feed.py
backend/app/routes/user.py
backend/app/services/auth.py
backend/app/services/feed.py
backend/app/repositories/auth_repo.py
backend/app/repositories/feed_repo.py
backend/app/repositories/post_repo.py
backend/app/repositories/user_repo.py
BubblerApp/BubblerApp/AuthSession.swift
BubblerApp/BubblerApp/ContentView.swift
BubblerApp/BubblerApp/FeedView.swift
scripts/seed_db.py
```

**Delete (only after Phase 1.4 conditions met):**

```
BubblerApp/BubblerApp/GoogleService-Info.plist
(Firebase SPM dependency in Xcode)
```

---

## When You're Stuck

1. **Import error on startup** — route imports wrong module name? Check `app/services/` filenames.
2. **Pool not found** — is service built with `pool` in `startup.py`?
3. **401 on iOS** — token expired or `Authorization` header missing?
4. **Empty feed** — seed data? Embeddings present? Check `get_similar_posts` returns rows.
5. **Tests fail on CI** — schema applied before pytest? Env vars set in workflow?

---

## Next Action

If you only do **one thing** next:

> **Phase 0, Steps 0.1–0.3** — fix route imports, align auth login flow, register feed + user routers in `startup.py`.

Then add **`test_auth.py`** (Phase 6.1) so the refactor stays wired.

That unlocks JWT (Phase 1), Firebase removal, and everything downstream.
