# Bubbler Roadmap — What to Do Next

This document is a step-by-step plan for a **solo developer** building Bubbler. It uses plain language, points to exact files, and is updated to match the **current codebase** (not the original plan).

---

## Where You Are Today (Quick Summary)

| Area | Status |
|------|--------|
| Backend folder structure (routes → services → repositories) | ✅ In place |
| Dependency injection (`backend/app/api/deps.py`) | ✅ Done |
| `requirements.txt` with real packages | ✅ Done |
| PostgreSQL schema draft (`backend/app/db/schema.sql`) | ✅ Updated (needs alignment with models) |
| `UserPreferencesRepository` (`user_pref_repo.py`) | ✅ Created |
| Feed algorithm services (similarity, graph, ranking, strategy) | 🟡 Written but not fully wired |
| Edge builder (`edge_builder_repo.py`) | 🟡 Created, not called yet |
| `main.py` lifespan + asyncpg pool | 🟡 Done, but credentials are still placeholders |
| iOS app (`BubblerApp/`) with polished UI | ✅ Login, feed, profile, settings screens |
| Firebase authentication on iOS | ✅ Working (`AuthSession.swift`) |
| iOS ↔ FastAPI connection | ❌ Not started (`BubblerApp/` has no `APIClient`) |
| Graph path UI (pick next post from bubbles) | ❌ Not built |
| Algorithm settings (diversity, randomness, topics) | ❌ UI placeholders only |
| Backend running end-to-end with seeded data | ❌ Blocked by config + schema mismatches |

**The big picture:** You have made solid progress on **both sides independently** — the backend has services and repos, and the iOS app has a real UI with Firebase login. They are not connected yet. Your next work should be: (1) finish backend foundation, (2) hook the iOS app to the API, (3) replace the mock feed with the graph path loop.

---

## Important: Two Folders to Know About

| Folder | Role today |
|--------|------------|
| `BubblerApp/` | **Active Xcode project.** Firebase auth, `FeedView`, `LoginView`, `ProfileView`, `SettingsView`, `BubbleDetail`. This is where iOS work should happen. |
| `ios-app/` | Older skeleton with `APIClient.swift` and `FeedViewModel.swift`. Useful as a reference, but do not build two apps — copy patterns from here into `BubblerApp/`. |

---

## How to Read This Roadmap

- Phases build on each other. Do them **in order**.
- ✅ = already done (may still need small fixes noted inline).
- 🟡 = started but incomplete.
- Steps without a marker are still to do.
- Code blocks are examples — adjust to match your file as you go.

---

## Phase 0 — Finish the Backend Foundation

**Goal:** Start the API, connect to Postgres, and get `GET /feed/{user_id}` returning real JSON.

Much of Phase 0 from the original roadmap is done. What remains is wiring, fixes, and alignment.

### ✅ Step 0.1 — Fix `requirements.txt` (done)

**File:** `backend/requirements.txt` — already has FastAPI, asyncpg, sentence-transformers, etc.

### Step 0.2 — Move database config out of `main.py`

**Why:** `backend/app/main.py` still has placeholder credentials (`REPLACE`, `THISTOO`). `backend/app/db/base.py` is empty. You want one place for the connection string.

**Create:** `backend/app/core/config.py`

```python
import os
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://bubbler:bubbler@localhost:5432/bubbler",
)
```

**Create:** `backend/.env.example` (commit this, not `.env`):

```env
DATABASE_URL=postgresql://bubbler:bubbler@localhost:5432/bubbler
JWT_SECRET=change-me-in-production
```

**Update:** `backend/app/main.py` — use `DATABASE_URL` instead of hard-coded placeholders:

```python
from .core.config import DATABASE_URL

app.state.pool = await asyncpg.create_pool(
    dsn=DATABASE_URL,
    min_size=1,
    max_size=10,
)
```

### 🟡 Step 0.3 — Align schema, models, and seed script (started, needs fixes)

**File:** `backend/app/db/schema.sql` — you updated this to valid PostgreSQL with `vector(384)`, `topic_id`, and `post_topics`. Good.

**Problem:** Other files still assume the old shape:

| File | Mismatch |
|------|----------|
| `scripts/seed_db.py` | Inserts into `topic` column — schema uses `topic_id` |
| `backend/app/models/user_profile.py` | Expects `preferred_topics`, `blacklisted_topics`, `strategy_weights` |
| `schema.sql` `user_profiles` | Only has `embedding`, `diversity_tolerance`, `randomness` — missing topic lists and strategy weights |
| `user_pref_repo.py` line 32 | Typo: `preferrred_topics` (three r's) |

**Fix the schema** — extend `user_profiles` in `backend/app/db/schema.sql`:

```sql
CREATE TABLE user_profiles (
    user_id INTEGER PRIMARY KEY REFERENCES users(id),
    embedding vector(384),
    diversity_tolerance FLOAT CHECK (diversity_tolerance BETWEEN 0 AND 1) DEFAULT 0.4,
    randomness FLOAT DEFAULT 0.3,
    preferred_topics TEXT[] NOT NULL DEFAULT '{}',
    blacklisted_topics TEXT[] NOT NULL DEFAULT '{}',
    use_view_time BOOLEAN NOT NULL DEFAULT FALSE,
    view_time_weight FLOAT DEFAULT 0.1,
    strategy_weights JSONB NOT NULL DEFAULT '{"similar":0.7,"graph":0.2,"opposite":0.0,"random":0.1}'
);
```

**Fix** `backend/app/repositories/user_pref_repo.py` line 32:

```python
preferred_topics=list(rows["preferred_topics"]),  # fix typo
```

**Fix** `scripts/seed_db.py` — either insert topics first and use `topic_id`, or add a `topic TEXT` column back to `posts` for simplicity during MVP:

```python
# Simple MVP: add topics, then posts
topic_id = await conn.fetchval(
    "INSERT INTO topics (name) VALUES ($1) ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name RETURNING id",
    topic,
)
await conn.execute(
    "INSERT INTO posts (user_id, content, topic_id, embedding) VALUES ($1, $2, $3, $4)",
    user_id, content, topic_id, vector,
)
```

Also add `UNIQUE` on `users.email` if you use `ON CONFLICT (email)` in the seed script.

### ✅ Step 0.4 — `user_pref_repo.py` (done, fix typo above)

**File:** `backend/app/repositories/user_pref_repo.py` — class is named `UserPreferencesRepository` (used in `deps.py`).

### ✅ Step 0.5 — Dependency injection (done)

**File:** `backend/app/api/deps.py` — full wiring for repos and services including `getFeedService`. No changes needed unless you add new services.

### 🟡 Step 0.6 — Repository methods (partially done, fix bugs)

**File:** `backend/app/repositories/feed_repo.py`

| Method | Status |
|--------|--------|
| `getSimilarPosts` | ✅ Works |
| `getOppositePosts` | ✅ Added |
| `getRandomPosts` | ✅ Added |
| `getPostsByIds` | ❌ **Bug** — SQL uses `ORDER BY RANDOM()` instead of filtering by IDs |

Fix `getPostsByIds`:

```python
async def getPostsByIds(self, ids: list):
    if not ids:
        return []
    async with self.pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT id, content, topic_id, created_at, user_id
            FROM posts
            WHERE id = ANY($1::uuid[])
            """,
            ids,
        )
    return [dict(r) for r in rows]
```

Fix `getNewSessionPosts` — SQL still has a syntax error (missing comma after `SELECT *`):

```python
post = await conn.fetchrow(
    """
    SELECT *, 1 - (embedding <=> $1::vector) AS similarity
    FROM posts
    WHERE topic_id = $2
    ORDER BY ABS((1 - (embedding <=> $1::vector)) - $3)
    LIMIT 1
    """,
    yesterdayPost, likedTopic, target,
)
```

### 🟡 Step 0.7 — Seed script (started, fix schema alignment)

**File:** `scripts/seed_db.py` — has sample posts and embedding logic. Update to match schema (see Step 0.3), then run:

```bash
python scripts/seed_db.py
```

### Step 0.8 — Fix feed routes and service bugs

**File:** `backend/app/api/routes/feed.py` — routes exist but do not pass `user_id` or `await` async methods:

```python
from fastapi import APIRouter, Depends, Query
from ...services.feed_service import FeedService
from ..deps import getFeedService

router = APIRouter()

@router.get("/{user_id}")
async def get_feed(
    user_id: int,
    q: str = Query(default=""),
    service: FeedService = Depends(getFeedService),
):
    return await service.getFeed(user_id, q)

@router.get("/{user_id}/session")
async def get_session_posts(
    user_id: int,
    service: FeedService = Depends(getFeedService),
):
    return await service.getNewSessionPosts(user_id)
```

**File:** `backend/app/services/feed_service.py` — fix these bugs:

```python
# line 29: use instance, not class
embedding = self.EmbeddingService.embedText(userInput)

# line 48: missing await
expandedPosts = await self.repo.getPostsByIds(list(allIds))

# line 80: wrong attribute name (model uses diversity_tolerance)
return await self.repo.getNewSessionPosts(prefs.diversity_tolerance, [], None)
```

**File:** `backend/app/services/strategy_service.py` — `getOppositePosts` exists in the repo but strategy still has `pass`:

```python
if prefs.strategy_weights.get("opposite", 0) > 0:
    opposite = await self.repo.getOppositePosts(embedding, limit=10)
    strategies.append(("opposite", opposite))
```

Remove stale TODO comments for `getPostsByIds` and `getRandomPosts` — those methods exist now.

**File:** `backend/app/services/post_service.py` — use instance method:

```python
embedded = self.EmbeddingService.embedText(post)
```

**Checkpoint:** Run `uvicorn app.main:app --reload` from `backend/`, open `http://127.0.0.1:8000/docs`, call `GET /feed/1`. You should get a JSON list of posts.

---

## Phase 1 — Connect the iOS App to the Backend

**Goal:** `BubblerApp/` loads real posts from your API instead of hard-coded placeholder cards.

**Why now:** You already have a polished `FeedView` and working Firebase login. The missing piece is network code.

### Step 1.1 — Add `APIClient` to `BubblerApp/`

**Create:** `BubblerApp/BubblerApp/APIClient.swift`

Copy the pattern from `ios-app/BubblerApp/App/Services/APIClient.swift`, but point at localhost:

```swift
import Foundation

final class APIClient {
    static let shared = APIClient()

    // Simulator reaches your Mac at 127.0.0.1
    private let baseURL = "http://127.0.0.1:8000"

    func get<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }
}
```

Add the file to your Xcode target (`BubblerApp.xcodeproj`).

### Step 1.2 — Add a `Post` model to `BubblerApp/`

**Create:** `BubblerApp/BubblerApp/Post.swift`

```swift
import Foundation

struct Post: Codable, Identifiable {
    let id: UUID
    let content: String
    let topicId: UUID?
    let userId: Int?
    let score: Double?
}
```

Match field names to whatever JSON your feed endpoint actually returns — check `/docs` first.

### Step 1.3 — Add a `FeedViewModel` and wire `FeedView`

**Create:** `BubblerApp/BubblerApp/FeedViewModel.swift`

```swift
import Foundation

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var errorMessage: String?

    // Until Firebase UID is mapped to a backend user id, hard-code 1
    private let userId = 1

    func loadFeed() async {
        do {
            posts = try await APIClient.shared.get("/feed/\(userId)")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

**Update:** `BubblerApp/BubblerApp/FeedView.swift` — replace hard-coded `feedCard(...)` calls with real data:

```swift
struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()

    var body: some View {
        // ... keep your existing gradient + header ...
        VStack(spacing: 18) {
            if let error = viewModel.errorMessage {
                Text(error).foregroundColor(.white)
            }
            ForEach(viewModel.posts) { post in
                feedCard(
                    bubble: "Post",
                    title: post.content,
                    subtitle: "Score: \(post.score ?? 0)",
                    color: .blue
                )
            }
        }
        .task { await viewModel.loadFeed() }
    }
}
```

### Step 1.4 — Bridge Firebase users to backend users

**Current state:** iOS uses **Firebase Auth** (`AuthSession.swift`). The backend uses its own `users` table and `auth` routes. These are separate systems today.

**Short-term MVP (pick one):**

**Option A — Firebase only on client, backend trusts a header (fastest for solo dev):**
- After Firebase login, call `POST /auth/register` once to create a matching backend user (use Firebase UID as username or store mapping).
- Send `X-User-Id: 1` header from `APIClient` until you build proper token exchange.

**Option B — Sync on first login:**

**Update:** `BubblerApp/BubblerApp/AuthSession.swift` — after successful sign-in:

```swift
// After Firebase sign-in succeeds:
if let email = Auth.auth().currentUser?.email {
    try await APIClient.shared.registerIfNeeded(email: email)
}
```

**Create:** a small `BackendAuthService.swift` that calls your FastAPI `/auth/register` endpoint.

**File to extend:** `backend/app/api/routes/auth.py` — still uses `login/{id}` and `register/{id}` with a user id in the URL. Simplify when you tackle Phase 4.

### Step 1.5 — Deprecate `ios-app/` duplicate

Once `APIClient` lives in `BubblerApp/`, treat `ios-app/` as archived. Add a one-line note to `README.md` when you're ready (optional).

**Checkpoint:** Log in on the simulator → `FeedView` shows posts from Postgres, not placeholder NASA/AI headlines.

---

## Phase 2 — Build the Graph Experience (Core Product)

**Goal:** User sees **one post** and **a few choices** for what to read next — the DAG path, not a scrolling list.

**Plain-language explanation:**

- Each post is a **node**.
- Each link between posts is an **edge** (in the `edges` table).
- The user's **path** is the sequence of posts they chose.
- The algorithm picks which edges to show as bubbles.

### 🟡 Step 2.1 — Build edges when posts are created (repo exists, not wired)

**File:** `backend/app/repositories/edge_builder_repo.py` — `buildEdgesForPost` already exists.

**Still to do:**

1. Add `getEdgeBuilderRepo` to `backend/app/api/deps.py`
2. Call it from `backend/app/services/post_service.py` after inserting a post:

```python
async def postUserPosts(self, user_id, content):
    embedded = self.EmbeddingService.embedText(content)
    post = await self.repo.postUserPosts(user_id, content, embedded)
    await self.edgeBuilder.buildEdgesForPost(post["id"], embedded)
    return post
```

3. Run edge building for existing posts in `scripts/seed_db.py` after insert loop

**Note:** `ON CONFLICT DO NOTHING` in the edge insert requires a unique constraint on `(from_post_id, to_post_id)` — add that to `schema.sql` if inserts fail silently.

### Step 2.2 — Add a “next posts” API endpoint

**Create:** `backend/app/api/routes/graph.py`

```python
from fastapi import APIRouter, Depends
from ...services.graph_service import GraphService
from ..deps import getGraphService, getFeedRepo
from ...repositories.feed_repo import FeedRepository

router = APIRouter()

@router.get("/posts/{post_id}/next")
async def get_next_posts(
    post_id: str,
    graph: GraphService = Depends(getGraphService),
    feed_repo: FeedRepository = Depends(getFeedRepo),
):
    neighbors = await graph.repo.getNeighbors(post_id, limit=4)
    if not neighbors:
        return []
    ids = [n["to_post_id"] for n in neighbors]
    return await feed_repo.getPostsByIds(ids)
```

**Update:** `backend/app/services/graph_service.py` — add a helper if you prefer logic in the service layer:

```python
async def getNextChoices(self, post_id: str, limit: int = 4):
    neighbors = await self.repo.getNeighbors(post_id, limit=limit)
    return [n["to_post_id"] for n in neighbors]
```

**Update:** `backend/app/main.py`:

```python
from .api.routes import graph
app.include_router(graph.router, prefix="/graph", tags=["graph"])
```

### Step 2.3 — Graph feed screen on iOS

The current `FeedView` is a **linear list with mock data**. The graph experience is different: one current post + choice bubbles.

**Create:** `BubblerApp/BubblerApp/GraphFeedView.swift`

```swift
struct GraphFeedView: View {
    @StateObject private var vm = GraphFeedViewModel()

    var body: some View {
        VStack(spacing: 20) {
            if let current = vm.currentPost {
                // Reuse your feedCard styling or a simpler post card
                Text(current.content)
                    .foregroundColor(.white)
                    .padding()
            }

            Text("Where next?")
                .font(.headline)
                .foregroundColor(.white)

            ForEach(vm.choices) { choice in
                Button(choice.content) {
                    Task { await vm.choose(choice) }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .task { await vm.startSession() }
    }
}
```

**Create:** `BubblerApp/BubblerApp/GraphFeedViewModel.swift`

```swift
@MainActor
final class GraphFeedViewModel: ObservableObject {
    @Published var currentPost: Post?
    @Published var choices: [Post] = []
    private var path: [Post] = []
    private let userId = 1

    func startSession() async {
        // GET /feed/{userId}/session -> pick first post
        // GET /graph/posts/{id}/next -> fill choices
    }

    func choose(_ post: Post) async {
        path.append(post)
        currentPost = post
        // fetch next choices
        // POST /interactions to record "explore"
    }
}
```

**Update:** `BubblerApp/BubblerApp/ContentView.swift` — swap `FeedView()` for `GraphFeedView()` once the loop works.

**Reuse:** `BubbleDetail.swift` styling can inspire bubble choice buttons.

### Step 2.4 — Record interactions

**File:** `backend/app/repositories/interaction_repo.py` — currently only has `__init__`. Add:

```python
async def record(self, user_id: int, post_id: str, type: str, view_time: float = 0):
    async with self.pool.acquire() as conn:
        await conn.execute(
            """
            INSERT INTO interactions (user_id, post_id, type, view_time)
            VALUES ($1, $2, $3, $4)
            """,
            user_id, post_id, type, view_time,
        )

async def getRecentInteractions(self, user_id: int, limit: int = 50):
    async with self.pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT i.*, pt.topic_id
            FROM interactions i
            JOIN posts p ON p.id = i.post_id
            LEFT JOIN post_topics pt ON pt.post_id = p.id
            WHERE i.user_id = $1
            ORDER BY i.created_at DESC
            LIMIT $2
            """,
            user_id, limit,
        )
    return rows
```

Add `view_time` column to `interactions` in `schema.sql` if missing.

**Update:** `backend/app/api/routes/interactions.py` — fix the route (currently calls `InteractionService.getUserInteractions()` without `id` or `await`):

```python
@router.post("/{user_id}")
async def record_interaction(
    user_id: int,
    body: InteractionCreate,
    service: InteractionService = Depends(getInteractionService),
):
    return await service.record(user_id, body)
```

**Update:** `backend/app/services/preference_service.py` — fix attribute name:

```python
prefs.preferred_topics = [t[0] for t in sortedTopics[:5]]  # not preferredTopics
```

**Checkpoint:** Tap through 3–4 posts. Each tap loads new choices. That is Bubbler's core loop.

---

## Phase 3 — User-Controlled Algorithm

**Goal:** User sets diversity, randomness, topic lists, and view-time weighting — per `docs/api_contracts.md`.

### Step 3.1 — Preferences API on the backend

**File:** `backend/app/api/routes/users.py` — currently only has profile stubs. Add:

```python
from pydantic import BaseModel
from ..deps import getUserPrefRepo
from ...repositories.user_pref_repo import UserPreferencesRepository

class PrefsUpdate(BaseModel):
    diversity_tolerance: float | None = None
    randomness: float | None = None
    preferred_topics: list[str] | None = None
    blacklisted_topics: list[str] | None = None
    use_view_time: bool | None = None
    strategy_weights: dict[str, float] | None = None

@router.get("/{user_id}/preferences")
async def get_preferences(user_id: int, repo: UserPreferencesRepository = Depends(getUserPrefRepo)):
    return await repo.getPrefs(user_id)

@router.put("/{user_id}/preferences")
async def update_preferences(user_id: int, body: PrefsUpdate, repo: UserPreferencesRepository = Depends(getUserPrefRepo)):
    return await repo.updatePrefs(user_id, body)
```

Add `updatePrefs` to `backend/app/repositories/user_pref_repo.py`.

### Step 3.2 — Algorithm settings screen on iOS

**File:** `BubblerApp/BubblerApp/SettingsView.swift` — has a "Bubble Sensitivity" row placeholder. Replace with a real screen.

**Create:** `BubblerApp/BubblerApp/AlgorithmSettingsView.swift`

```swift
struct AlgorithmSettingsView: View {
    @State private var randomness: Double = 0.3
    @State private var diversity: Double = 0.4
    @State private var useViewTime = false

    var body: some View {
        Form {
            Section("Discovery") {
                Slider(value: $randomness, in: 0...1) {
                    Text("Randomness")
                }
                Slider(value: $diversity, in: 0...1, step: 0.05) {
                    Text("Diversity")
                }
            }
            Section("Engagement") {
                Toggle("Count time spent reading", isOn: $useViewTime)
            }
            Button("Save") {
                Task { await savePreferences() }
            }
        }
        .navigationTitle("Your Algorithm")
    }

    func savePreferences() async {
        // PUT /users/{id}/preferences via APIClient
    }
}
```

Wire the NavigationLink from `SettingsView` "Bubble Sensitivity" row to this view.

### Step 3.3 — Wire opposite posts in strategy service

**File:** `backend/app/services/strategy_service.py` — see Phase 0, Step 0.8. `getOppositePosts` already lives in `feed_repo.py`.

### Step 3.4 — Track view time on iOS

In `GraphFeedView`, record how long the user reads before tapping a choice:

```swift
@State private var viewStartedAt = Date()

.onAppear { viewStartedAt = Date() }

// when user taps a bubble:
let seconds = Date().timeIntervalSince(viewStartedAt)
// send with interaction POST
```

**Checkpoint:** Cranking randomness shuffles results. Blacklisting a topic removes those posts.

---

## Phase 4 — Auth Unification, Tests, and Deploy

**Goal:** Production-ready basics — one auth story, tests, easy local setup.

### Step 4.1 — Decide: Firebase + backend, or backend-only?

**Current state:**

| Layer | Auth |
|-------|------|
| iOS (`AuthSession.swift`) | Firebase Auth ✅ |
| Backend (`auth.py`, `auth_service.py`) | Custom email/password with `PasswordService` (bcrypt) |

You do **not** need two login systems long-term. Common solo-dev paths:

1. **Keep Firebase for iOS**, verify Firebase ID tokens on the backend (add middleware in FastAPI).
2. **Drop Firebase**, use backend JWT only, simplify iOS to call `/auth/login`.

**File:** `backend/app/api/routes/auth.py` — fix route paths (missing `/` prefix: `"login/{id}"` → `"/login"`).

**File:** `backend/app/core/security.py` — empty. Add JWT helpers when you pick backend tokens.

**File:** `backend/app/services/password_service.py` — methods should be `@staticmethod` or use `self` consistently (currently defined without `self` on instance methods).

### Step 4.2 — Add basic tests

**Create:** `backend/tests/test_feed.py`

```python
import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app

@pytest.mark.asyncio
async def test_app_starts():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/docs")
    assert response.status_code == 200
```

Add `httpx` and `pytest` to `requirements.txt`.

### Step 4.3 — Docker Compose for Postgres

**Create:** `docker-compose.yml` at repo root:

```yaml
services:
  db:
    image: pgvector/pgvector:pg16
    environment:
      POSTGRES_USER: bubbler
      POSTGRES_PASSWORD: bubbler
      POSTGRES_DB: bubbler
    ports:
      - "5432:5432"
    volumes:
      - bubbler_pg:/var/lib/postgresql/data

volumes:
  bubbler_pg:
```

Then: `docker compose up -d` → apply `schema.sql` → run `seed_db.py`.

### Step 4.4 — Remaining cleanup checklist

| Issue | File | Fix |
|-------|------|-----|
| `Post.id` type mismatch (`int` vs `UUID`) | `backend/app/models/post.py` | Use `UUID` |
| `feed_service.py` missing `await` on `getPostsByIds` | `feed_service.py` ~line 48 | Add `await` |
| `EmbeddingService` called as class not instance | `feed_service.py`, `post_service.py` | Use `self.` |
| `interactions` route broken | `interactions.py` | Pass `id`, `await`, use instance |
| `ranking_service.py` uses `post["topic"]` | `ranking_service.py` | Join topic name or use `topic_id` |
| `SearchView` placeholder | `BubblerApp/.../SearchView.swift` | Defer until graph loop works |
| Profile shows placeholder stats | `ProfileView.swift` | Wire to `/users/{id}/profile` later |

---

## Suggested Timeline (Solo Dev)

| Phase | Focus | Rough time | Status |
|-------|-------|------------|--------|
| 0 | Backend foundation + bug fixes | 1 weekend | 🟡 ~70% done |
| 1 | iOS ↔ API connection | 1 weekend | ❌ Not started |
| 2 | Graph bubbles + path | 2–3 weekends | ❌ Not started |
| 3 | Algorithm settings | 1–2 weekends | ❌ UI placeholders only |
| 4 | Auth unification, tests, deploy | 2+ weekends | ❌ Not started |

Do **not** polish `SearchView` or profile stats until Phase 2's graph loop works.

---

## What to Avoid (Common Solo-Dev Traps)

1. **Maintaining two iOS folders** — `BubblerApp/` is canonical; copy from `ios-app/` then ignore it.
2. **Perfecting the ML model** — MiniLM + pgvector is enough for months.
3. **Building a visual node-graph diagram** — bubbles + a path trail (`ProfileView` "Bubble Trail") is enough.
4. **Firebase AND custom auth forever** — pick a unified approach in Phase 4.
5. **Tuning the algorithm before seed data** — seed 50–100 posts with edges first.

---

## File Checklist (Updated)

**Already created (verify/fix, don't recreate):**

```
backend/app/api/deps.py
backend/app/repositories/user_pref_repo.py
backend/app/repositories/edge_builder_repo.py
backend/app/services/password_service.py
backend/requirements.txt
BubblerApp/BubblerApp/AuthSession.swift
BubblerApp/BubblerApp/LoginView.swift
BubblerApp/BubblerApp/CreateAccountView.swift
BubblerApp/BubblerApp/FeedView.swift
BubblerApp/BubblerApp/ProfileView.swift
BubblerApp/BubblerApp/SettingsView.swift
BubblerApp/BubblerApp/BubbleDetail.swift
scripts/seed_db.py
```

**Still to create:**

```
backend/app/core/config.py
backend/.env.example
backend/app/api/routes/graph.py
backend/tests/test_feed.py
docker-compose.yml
BubblerApp/BubblerApp/APIClient.swift
BubblerApp/BubblerApp/Post.swift
BubblerApp/BubblerApp/FeedViewModel.swift
BubblerApp/BubblerApp/GraphFeedView.swift
BubblerApp/BubblerApp/GraphFeedViewModel.swift
BubblerApp/BubblerApp/AlgorithmSettingsView.swift
```

**Edit next (highest priority):**

```
backend/app/main.py
backend/app/db/schema.sql
backend/app/api/routes/feed.py
backend/app/services/feed_service.py
backend/app/services/strategy_service.py
backend/app/repositories/feed_repo.py
backend/app/repositories/user_pref_repo.py
backend/app/repositories/interaction_repo.py
scripts/seed_db.py
BubblerApp/BubblerApp/FeedView.swift
BubblerApp/BubblerApp/ContentView.swift
```

---

## When You're Stuck

Debug in this order:

1. **Database** — `SELECT * FROM posts` returns rows with embeddings?
2. **API** — `/docs` works and `GET /feed/1` returns JSON?
3. **iOS network** — Simulator uses `127.0.0.1:8000`, not `api.bubbler.com`?
4. **JSON shape** — Swift `Post` fields match API keys (`user_id` vs `userId`)?
5. **Firebase vs backend user** — Is the `user_id` you pass to `/feed/{id}` a real row in `users`?
6. **Algorithm** — Log `post["score"]` in `ranking_service.py` only after 1–5 work.

---

## Next Action (Start Here)

If you only do **one thing** next:

> Finish **Phase 0, Steps 0.2 and 0.8** — add `config.py`, fix `feed.py` routes and `feed_service.py` bugs, then confirm `GET /feed/1` returns posts in Swagger.

Then move to **Phase 1** — add `APIClient.swift` to `BubblerApp/` and replace the mock cards in `FeedView.swift` with real data.

That connects the two halves of the project and unlocks the graph work in Phase 2.
