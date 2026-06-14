# Bubbler Roadmap — What to Do Next

This document is a step-by-step plan for a **solo developer** building Bubbler. 
It uses plain language and points to exact files.

---

## Where You Are Today (Quick Summary)

You have the **right shape** of the project:

| Area | Status |
|------|--------|
| Backend folder structure (routes → services → repositories) | ✅ Started |
| Feed algorithm ideas (similarity, graph expansion, preferences) | ✅ Sketched in code |
| Database schema idea (posts, edges, interactions, user profiles) | ✅ Drafted |
| iOS app skeleton (Feed, Post models, API client) | ✅ Started |
| Everything wired together and running end-to-end | ❌ Not yet |
| Graph UI (the main product idea) | ❌ Not built |
| User preference controls in the app | ❌ Not built |

**The big picture:** most of the *ideas* live in `backend/app/services/`, but several pieces are incomplete, some files are missing, and the iOS app does not talk to a working backend yet. Your next work should focus on **one small vertical slice** — login → see one post → tap a “next” option → see related posts — before polishing the algorithm.

---

## How to Read This Roadmap

Each phase builds on the last. Do them **in order**. Within each phase, the steps are numbered — do those in order too.

- **Estimated effort** is rough, for one person working part-time.
- **Code blocks** show what to add or change. They are examples, not copy-paste guarantees — adjust names to match your project as you go.
- Only create or edit files listed in each step unless you discover a small dependency (e.g. a missing import).

---

## Phase 0 — Get the Backend Running Locally

**Goal:** You can start the API, hit it in a browser or with `curl`, and get a real response from PostgreSQL.

**Why first:** Right now `backend/app/db/base.py` uses `psycopg2` (synchronous), but your repositories use `async`/`await`. Routes call services without passing `userId`. `user_pref_repo.py` is imported in `feed_service.py` but **does not exist**. Until the foundation works, nothing else will.

### `DONE` Step 0.1 — Fix `requirements.txt` `DONE`

**File:** `backend/requirements.txt`

Replace the current system-wide package dump with a small, project-specific list:

```txt
fastapi>=0.110.0
uvicorn[standard]>=0.27.0
asyncpg>=0.29.0
pydantic>=2.0.0
python-jose[cryptography]>=3.3.0
passlib[bcrypt]>=1.7.4
sentence-transformers>=2.2.0
pgvector>=0.2.0
python-dotenv>=1.0.0
```

Install:

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### Step 0.2 — Add environment-based database config

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

**Update:** `backend/app/db/base.py`

```python
import asyncpg
from ..core.config import DATABASE_URL

pool = None

async def init_db():
    global pool
    pool = await asyncpg.create_pool(DATABASE_URL)

async def close_db():
    global pool
    if pool:
        await pool.close()
```

**Update:** `backend/app/main.py` — connect on startup:

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI
from .db.base import init_db, close_db
from .api.routes import auth, feed, posts, users

@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    yield
    await close_db()

app = FastAPI(lifespan=lifespan)
app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(feed.router, prefix="/feed", tags=["feed"])
app.include_router(posts.router, prefix="/posts", tags=["posts"])
app.include_router(users.router, prefix="/users", tags=["users"])
```

### `DONE` Step 0.3 — Fix the SQL schema `DONE`

**File:** `backend/app/db/schema.sql`

The current file mixes SQLite-style syntax (`DATETIME`, `SERIAL` in wrong places) with PostgreSQL. Rewrite it as valid PostgreSQL. Key fixes:

- `users.id` should be a single primary key type (use `SERIAL PRIMARY KEY` or `UUID`).
- `posts.embedding` needs a dimension, e.g. `vector(384)` for MiniLM.
- Foreign keys must reference the same type (`INTEGER` vs `UUID` must match everywhere).

Minimal working version to start:

```sql
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE topics (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    parent_topic_id INTEGER REFERENCES topics(id)
);

CREATE TABLE posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id INTEGER NOT NULL REFERENCES users(id),
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    embedding vector(384),
    topic TEXT
);

CREATE INDEX posts_embedding_idx ON posts
USING hnsw (embedding vector_cosine_ops);

CREATE TABLE edges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_post_id UUID NOT NULL REFERENCES posts(id),
    to_post_id UUID NOT NULL REFERENCES posts(id),
    edge_type TEXT NOT NULL,  -- 'similar', 'opposite', 'topic'
    weight FLOAT NOT NULL DEFAULT 1.0
);

CREATE TABLE interactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id INTEGER NOT NULL REFERENCES users(id),
    post_id UUID NOT NULL REFERENCES posts(id),
    type TEXT NOT NULL,  -- 'like', 'skip', 'explore'
    view_time FLOAT DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE user_profiles (
    user_id INTEGER PRIMARY KEY REFERENCES users(id),
    diversity_tolerance INTEGER NOT NULL DEFAULT 40,
    randomness FLOAT NOT NULL DEFAULT 0.3,
    preferred_topics TEXT[] NOT NULL DEFAULT '{}',
    blacklisted_topics TEXT[] NOT NULL DEFAULT '{}',
    use_view_time BOOLEAN NOT NULL DEFAULT FALSE,
    view_time_weight FLOAT NOT NULL DEFAULT 0.1,
    strategy_weights JSONB NOT NULL DEFAULT '{"similar":0.5,"graph":0.2,"opposite":0.2,"random":0.1}'
);
```

Run it against your local Postgres database before continuing.

### `DONE` Step 0.4 — Create the missing `user_pref_repo.py` `DONE`

**Create:** `backend/app/repositories/user_pref_repo.py`

```python
from ..models.user_profile import UserProfile
from ..db.base import pool

DEFAULT_PREFS = UserProfile(
    user_id=0,
    diversity_tolerance=40,
    randomness=0.3,
    preferred_topics=[],
    blacklisted_topics=[],
    strategy_weights={
        "similar": 0.5,
        "graph": 0.2,
        "opposite": 0.2,
        "random": 0.1,
    },
)

class UserPrefRepository:
    async def getPrefs(self, user_id: int) -> UserProfile:
        async with pool.acquire() as conn:
            row = await conn.fetchrow(
                "SELECT * FROM user_profiles WHERE user_id = $1",
                user_id,
            )
        if not row:
            return DEFAULT_PREFS.model_copy(update={"user_id": user_id})
        return UserProfile(
            user_id=row["user_id"],
            diversity_tolerance=row["diversity_tolerance"],
            randomness=row["randomness"],
            preferred_topics=list(row["preferred_topics"]),
            blacklisted_topics=list(row["blacklisted_topics"]),
            use_view_time=row["use_view_time"],
            view_time_weight=row["view_time_weight"],
            strategy_weights=dict(row["strategy_weights"]),
        )
```

### `DONE` Step 0.5 — Add dependency injection (wire services to routes) `DONE`

**Create:** `backend/app/api/deps.py`

This is the glue that tells FastAPI *how* to build a `FeedService` when a route asks for one:

```python
from ..db.base import pool
from ..repositories.feed_repo import FeedRepository
from ..repositories.graph_repo import GraphRepository
from ..repositories.user_pref_repo import UserPrefRepository
from ..repositories.interaction_repo import InteractionRepository
from ..services.feed_service import FeedService
from ..services.graph_service import GraphService
from ..services.ranking_service import RankingService
from ..services.strategy_service import StrategyService
from ..services.preference_service import PreferenceService
from ..services.embedding_service import EmbeddingService

def get_feed_service() -> FeedService:
    feed_repo = FeedRepository(pool)
    graph_repo = GraphRepository(pool)
    return FeedService(
        repo=feed_repo,
        GraphService=GraphService(graph_repo),
        RankingService=RankingService(),
        EmbeddingService=EmbeddingService(),
        StrategyService=StrategyService(feed_repo, GraphService(graph_repo)),
        PreferenceService=PreferenceService(),
        PrefRepo=UserPrefRepository(),
        InteractionRepo=InteractionRepository(pool),
    )
```

**Update:** `backend/app/api/routes/feed.py`

```python
from fastapi import APIRouter, Depends, Query
from ...services.feed_service import FeedService
from ...api.deps import get_feed_service

router = APIRouter()

@router.get("/{user_id}")
async def get_feed(
    user_id: int,
    q: str = Query(default="", description="Optional text to steer the feed"),
    service: FeedService = Depends(get_feed_service),
):
    return await service.getFeed(user_id, q)

@router.get("/{user_id}/session")
async def get_session_posts(
    user_id: int,
    service: FeedService = Depends(get_feed_service),
):
    return await service.getNewSessionPosts(user_id)
```

### `DONE` Step 0.6 — Fill in missing repository methods `DONE`

**File:** `backend/app/repositories/feed_repo.py`

Add these methods (your `feed_service.py` and `strategy_service.py` already expect them):

```python
async def getPostsByIds(self, ids: list):
    if not ids:
        return []
    async with self.pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT id, content, topic, created_at, user_id
            FROM posts
            WHERE id = ANY($1::uuid[])
            """,
            ids,
        )
    return [dict(r) for r in rows]

async def getRandomPosts(self, limit: int = 10):
    async with self.pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT id, content, topic, created_at, user_id
            FROM posts
            ORDER BY RANDOM()
            LIMIT $1
            """,
            limit,
        )
    return [dict(r) for r in rows]
```

Also fix `getNewSessionPosts` — the current SQL has a syntax error (`SELECT *` followed by `1 - ...` on the next line without a comma).

### `DONE` Step 0.7 — Seed fake data so you have something to show `DONE`

**File:** `scripts/seed_db.py`

```python
import asyncio
import asyncpg
from ml.embeddings.generate import embed

SAMPLE_POSTS = [
    ("I love building side projects.", "tech"),
    ("Morning runs clear my head.", "health"),
    ("This startup idea needs validation.", "startups"),
    ("Hot take: tabs over spaces.", "tech"),
]

async def main():
    conn = await asyncpg.connect("postgresql://bubbler:bubbler@localhost:5432/bubbler")

    user_id = await conn.fetchval(
        """
        INSERT INTO users (username, email, password_hash)
        VALUES ('demo', 'demo@bubbler.test', 'not-a-real-hash')
        ON CONFLICT (email) DO UPDATE SET username = EXCLUDED.username
        RETURNING id
        """
    )

    for content, topic in SAMPLE_POSTS:
        vector = embed(content)
        post_id = await conn.fetchval(
            """
            INSERT INTO posts (user_id, content, topic, embedding)
            VALUES ($1, $2, $3, $4)
            RETURNING id
            """,
            user_id, content, topic, vector,
        )
        print("Inserted post", post_id)

    await conn.close()

if __name__ == "__main__":
    asyncio.run(main())
```

**Checkpoint:** Run `uvicorn app.main:app --reload` from `backend/`, then open `http://127.0.0.1:8000/docs`. You should see your routes and get JSON back from `/feed/1`.

---

## Phase 1 — One Working End-to-End Path (Backend + iOS)

**Goal:** A user opens the iOS app, sees a list of posts from your real API, and can refresh the feed.

**Why now:** This proves the whole pipeline before you build the fancy graph UI.

### Step 1.1 — Pick one iOS app folder

You currently have two iOS locations:

- `ios-app/BubblerApp/` — has Feed, models, services (more complete)
- `BubblerApp/` — Xcode project with a “Hello, world” `ContentView.swift`

**Recommendation:** Treat `ios-app/` as the source of truth. Either move its files into the Xcode project under `BubblerApp/`, or point Xcode at `ios-app/`. Do not maintain both long-term.

### Step 1.2 — Point the API client at localhost

**File:** `ios-app/BubblerApp/App/Services/APIClient.swift`

For the simulator, `localhost` on the Mac is reachable as `127.0.0.1`:

```swift
import Foundation

class APIClient {
    static let shared = APIClient()

    // Change this when you deploy
    private let baseURL = "http://127.0.0.1:8000"

    func get<T: Decodable>(_ path: String, completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: baseURL + path) else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else { return }

            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
```

Add a `JSONDecoder` date strategy in `FeedViewModel` if your API returns ISO dates.

### Step 1.3 — Fix the feed API path

**File:** `ios-app/BubblerApp/App/Features/Feed/FeedViewModel.swift`

```swift
class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []

    // Hard-code user 1 until auth works
    private let userId = 1

    func loadFeed() {
        APIClient.shared.get("/feed/\(userId)") { (result: Result<[Post], Error>) in
            DispatchQueue.main.async {
                if case .success(let posts) = result {
                    self.posts = posts
                }
            }
        }
    }
}
```

Your `Post` model may need a simpler decode shape at first — match whatever JSON the backend actually returns (start without `author` until you join user data).

### Step 1.4 — Create a minimal `LoginView` (stub is fine)

**Create:** `ios-app/BubblerApp/App/Features/Auth/LoginView.swift`

```swift
import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthService

    var body: some View {
        VStack(spacing: 16) {
            Text("Bubbler")
                .font(.largeTitle)
            Button("Continue as demo user") {
                auth.isLoggedIn = true
            }
        }
    }
}
```

**File:** `ios-app/BubblerApp/App/Services/AuthService.swift` — ensure it has `@Published var isLoggedIn = false`.

### Step 1.5 — Hook `RootView` into the app entry point

Wire `RootView` as the root of your SwiftUI app (in whichever `*App.swift` file your Xcode target uses):

```swift
@main
struct BubblerAppApp: App {
    @StateObject private var auth = AuthService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
        }
    }
}
```

**Checkpoint:** Simulator shows posts from your seeded database. If the list is empty, debug the network call in Xcode’s console first, then the backend logs.

---

## Phase 2 — Build the Graph Experience (Core Product)

**Goal:** Instead of a scrolling list, the user sees **one post** and **a few “bubble” choices** for what to read next. That is the DAG path idea.

**Plain-language explanation:**

- Each post is a **node**.
- Each link to another post is an **edge** (stored in the `edges` table).
- The user’s **path** is the sequence of posts they chose.
- The feed algorithm picks which edges to show as bubbles.

### Step 2.1 — Build edges when posts are created

Right now `edges` is empty unless you fill it. When someone creates a post, find similar posts and insert edges.

**Create:** `backend/app/services/edge_builder_service.py`

```python
class EdgeBuilderService:
    def __init__(self, pool, embedding_service):
        self.pool = pool
        self.embedding_service = embedding_service

    async def build_edges_for_post(self, post_id, embedding):
        async with self.pool.acquire() as conn:
            # Similar neighbors
            similar = await conn.fetch(
                """
                SELECT id, 1 - (embedding <=> $1) AS similarity
                FROM posts
                WHERE id != $2
                ORDER BY embedding <=> $1
                LIMIT 5
                """,
                embedding, post_id,
            )
            for row in similar:
                await conn.execute(
                    """
                    INSERT INTO edges (from_post_id, to_post_id, edge_type, weight)
                    VALUES ($1, $2, 'similar', $3)
                    ON CONFLICT DO NOTHING
                    """,
                    post_id, row["id"], float(row["similarity"]),
                )
```

Call this from `post_service.py` after inserting a new post.

### Step 2.2 — Add a “next posts” API endpoint

This is what the graph UI will call when the user taps a bubble.

**Create:** `backend/app/api/routes/graph.py`

```python
from fastapi import APIRouter, Depends
from ...api.deps import get_graph_service  # you will add this in deps.py

router = APIRouter()

@router.get("/posts/{post_id}/next")
async def get_next_posts(post_id: str, service=Depends(get_graph_service)):
  """
  Returns up to 4 neighbor posts the user can choose from.
  """
  return await service.getNextChoices(post_id)
```

**Update:** `backend/app/services/graph_service.py`

```python
async def getNextChoices(self, post_id: str, limit: int = 4):
    neighbors = await self.repo.getNeighbors(post_id, limit=limit)
    if not neighbors:
        return []
    ids = [n["to_post_id"] for n in neighbors]
    # reuse FeedRepository.getPostsByIds or add a method on graph_repo
    return ids
```

**Update:** `backend/app/main.py` — register the router:

```python
from .api.routes import graph
app.include_router(graph.router, prefix="/graph", tags=["graph"])
```

### Step 2.3 — Build `BubbleView` on iOS

**Create:** `ios-app/BubblerApp/App/Components/BubbleView.swift`

```swift
import SwiftUI

struct BubbleView: View {
    let post: Post
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(post.content)
                .lineLimit(3)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}
```

### Step 2.4 — Replace the list feed with a graph feed screen

**Create:** `ios-app/BubblerApp/App/Features/Graph/GraphFeedView.swift`

```swift
import SwiftUI

struct GraphFeedView: View {
    @StateObject private var vm = GraphFeedViewModel()

    var body: some View {
        VStack {
            if let current = vm.currentPost {
                PostView(post: current)
            }

            Text("Where next?")
                .font(.headline)
                .padding(.top)

            ForEach(vm.choices) { choice in
                BubbleView(post: choice) {
                    vm.choose(choice)
                }
            }
        }
        .onAppear { vm.startSession() }
    }
}
```

**Create:** `ios-app/BubblerApp/App/Features/Graph/GraphFeedViewModel.swift`

```swift
class GraphFeedViewModel: ObservableObject {
    @Published var currentPost: Post?
    @Published var choices: [Post] = []
    private var path: [Post] = []

    func startSession() {
        // 1) GET /feed/1/session  -> first post
        // 2) GET /graph/posts/{id}/next -> bubble choices
    }

    func choose(_ post: Post) {
        path.append(post)
        currentPost = post
        // fetch next choices for this post
        // POST interaction type "explore" so the backend learns
    }
}
```

**Update:** `ios-app/BubblerApp/App/Components/RootView.swift` — show `GraphFeedView()` instead of `FeedView()` once this works.

### Step 2.5 — Record interactions when the user chooses

**Update:** `backend/app/repositories/interaction_repo.py`

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
            SELECT i.*, p.topic
            FROM interactions i
            JOIN posts p ON p.id = i.post_id
            WHERE i.user_id = $1
            ORDER BY i.created_at DESC
            LIMIT $2
            """,
            user_id, limit,
        )
    return rows
```

**Update:** `backend/app/services/preference_service.py` — fix attribute names to match `UserProfile` (`preferred_topics`, not `preferredTopics`).

**Checkpoint:** You can tap through 3–4 posts in a row. Each tap fetches new bubbles. That is Bubbler’s core loop.

---

## Phase 3 — User-Controlled Algorithm

**Goal:** The user can set diversity, randomness, topic lists, and whether view time counts — as described in `docs/api_contracts.md`.

### Step 3.1 — Preferences API

**Update:** `backend/app/api/routes/users.py`

```python
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from ...models.user_profile import UserProfile
from ...api.deps import get_user_pref_repo

router = APIRouter()

class PrefsUpdate(BaseModel):
    diversity_tolerance: int | None = None
    randomness: float | None = None
    preferred_topics: list[str] | None = None
    blacklisted_topics: list[str] | None = None
    use_view_time: bool | None = None
    strategy_weights: dict[str, float] | None = None

@router.get("/{user_id}/preferences")
async def get_preferences(user_id: int, repo=Depends(get_user_pref_repo)):
    return await repo.getPrefs(user_id)

@router.put("/{user_id}/preferences")
async def update_preferences(user_id: int, body: PrefsUpdate, repo=Depends(get_user_pref_repo)):
    return await repo.updatePrefs(user_id, body)
```

Add `updatePrefs` to `user_pref_repo.py` with an `UPDATE ...` SQL statement.

### Step 3.2 — Settings screen on iOS

**Create:** `ios-app/BubblerApp/App/Features/Profile/AlgorithmSettingsView.swift`

```swift
struct AlgorithmSettingsView: View {
    @State private var randomness: Double = 0.3
    @State private var diversity: Double = 40
    @State private var useViewTime = false

    var body: some View {
        Form {
            Section("Discovery") {
                Slider(value: $randomness, in: 0...1) {
                    Text("Randomness")
                }
                Slider(value: $diversity, in: 0...65, step: 1) {
                    Text("Diversity")
                }
            }
            Section("Engagement") {
                Toggle("Count time spent reading", isOn: $useViewTime)
            }
            Button("Save") {
                // PUT /users/{id}/preferences
            }
        }
        .navigationTitle("Your Algorithm")
    }
}
```

### Step 3.3 — Finish the strategy service TODOs

**File:** `backend/app/services/strategy_service.py`

| TODO | What to do | File to change |
|------|------------|----------------|
| Opposite posts | Add `getOppositePosts` in `feed_repo.py` — order by **lowest** similarity instead of highest | `feed_repo.py` |
| `getPostsByIds` | Already added in Phase 0 | `feed_repo.py` |
| `getRandomPosts` | Already added in Phase 0 | `feed_repo.py` |

Example opposite-post query:

```python
async def getOppositePosts(self, embedding, limit: int = 10):
    async with self.pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT id, content, topic,
                   1 - (embedding <=> $1) AS similarity
            FROM posts
            ORDER BY embedding <=> $1 DESC
            LIMIT $2
            """,
            embedding, limit,
        )
    return [dict(r) for r in rows]
```

### Step 3.4 — Track view time on iOS

In `GraphFeedView`, start a timer when `currentPost` appears. When the user taps a bubble, send `view_time` seconds with the interaction.

```swift
.onAppear { viewStartedAt = Date() }
// on choose:
let seconds = Date().timeIntervalSince(viewStartedAt)
```

**Checkpoint:** Changing randomness visibly shuffles bubble order. Blacklisting a topic removes those posts from results.

---

## Phase 4 — Auth, Polish, and Deploy Basics

**Goal:** Real accounts, safer config, and a path to TestFlight.

### Step 4.1 — Fix auth routes

**File:** `backend/app/api/routes/auth.py`

Current paths like `login/{id}` are unusual — login should not need a user id in the URL.

```python
@router.post("/register")
async def register(body: RegisterRequest, service: AuthService = Depends(get_auth_service)):
    return await service.register(body.username, body.email, body.password)

@router.post("/login")
async def login(body: LoginRequest, service: AuthService = Depends(get_auth_service)):
    return await service.login(body.email, body.password)
```

Return a JWT token. **File:** `backend/app/core/security.py` — add `create_access_token` / `decode_token`.

On iOS, store the token in Keychain and send `Authorization: Bearer ...` from `APIClient`.

### Step 4.2 — Add basic tests

**Create:** `backend/tests/test_feed.py`

```python
import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app

@pytest.mark.asyncio
async def test_health():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/")
    assert response.status_code == 200
```

You do not need 100% coverage. Start with: health check, feed returns a list, preferences save and load.

### Step 4.3 — Docker Compose for Postgres (optional but helpful)

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

Run `docker compose up -d`, apply `schema.sql`, run `seed_db.py`.

### Step 4.4 — Clean up inconsistencies (do as you touch files)

| Issue | Location | Fix |
|-------|----------|-----|
| `Post.id` is `int` in Python but `UUID` in SQL | `backend/app/models/post.py` | Use `UUID` type everywhere |
| `feed_service.py` calls `self.repo.getPostsByIds` without `await` | `feed_service.py` line ~60 | Add `await` |
| `EmbeddingService.embedText` called as static in `post_service.py` | `post_service.py` | Use `self.EmbeddingService.embedText` |
| `interactions` router not registered | `main.py` | Add `interactions.router` |
| iOS `PostView` expects `post.author` | `PostView.swift` | Add author to API or remove from UI for now |

---

## Suggested Timeline (Solo Dev)

| Phase | Focus | Rough time |
|-------|-------|------------|
| 0 | Backend runs locally | 1–2 weekends |
| 1 | iOS shows real posts | 1 weekend |
| 2 | Graph bubbles + path | 2–3 weekends |
| 3 | Algorithm settings | 1–2 weekends |
| 4 | Auth, tests, deploy | 2+ weekends |

Do **not** jump to Phase 4 before Phase 2 works. The graph loop is what makes Bubbler different from a normal feed app.

---

## What to Avoid (Common Solo-Dev Traps)

1. **Building both iOS folders** — pick one Xcode project and delete or ignore the other.
2. **Perfecting the ML model early** — MiniLM + pgvector is enough for months.
3. **Terraform / microservices** — one FastAPI app + one Postgres DB is correct for now.
4. **Graph visualization** — you do not need a visual node graph on screen. Bubbles + a path history is enough.
5. **Rewriting the algorithm before seed data exists** — seed 50–100 posts first, then tune weights.

---

## File Checklist (Quick Reference)

Files you will likely **create**:

```
backend/app/core/config.py
backend/app/api/deps.py
backend/app/repositories/user_pref_repo.py
backend/app/api/routes/graph.py
backend/app/services/edge_builder_service.py
backend/tests/test_feed.py
ios-app/.../Features/Auth/LoginView.swift
ios-app/.../Features/Graph/GraphFeedView.swift
ios-app/.../Features/Graph/GraphFeedViewModel.swift
ios-app/.../Components/BubbleView.swift
ios-app/.../Features/Profile/AlgorithmSettingsView.swift
```

Files you will likely **edit soon**:

```
backend/app/main.py
backend/app/db/base.py
backend/app/db/schema.sql
backend/app/repositories/feed_repo.py
backend/app/repositories/interaction_repo.py
backend/app/api/routes/feed.py
backend/app/services/feed_service.py
backend/app/services/preference_service.py
backend/app/services/post_service.py
ios-app/.../Services/APIClient.swift
ios-app/.../Features/Feed/FeedViewModel.swift
ios-app/.../Components/RootView.swift
scripts/seed_db.py
```

---

## When You're Stuck

Work in this debug order:

1. **Database** — can you `SELECT * FROM posts` and see rows?
2. **API** — does `/docs` show the route and return JSON?
3. **iOS network** — is the simulator hitting `127.0.0.1:8000` (not `api.bubbler.com`)?
4. **JSON shape** — does Swift `Post` match the keys the API sends (`user_id` vs `userId`)?
5. **Algorithm** — only after 1–4 work; log `post["score"]` in `ranking_service.py` to see ranking.

---

## Next Action (Start Here Tomorrow)

If you only do **one thing** next:

> Complete **Phase 0, Steps 0.1–0.7** so `GET /feed/1` returns seeded posts in Swagger UI.

That unlocks everything else.
