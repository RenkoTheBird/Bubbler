
TLDR ----- TLDR
Steps 2 and 3 are the main ones.

In a terminal, from the Bubbler/ folder/directory, run
./scripts/start_backend.sh --seed

If the database needs to be rebuilt (schema changed):
./scripts/start_backend.sh --rebuild-db --seed

When you see "Uvicorn running on..." you are clear.

Then in XCode:

1. Select the **BubblerApp** scheme
2. Choose an **iPhone Simulator** (for example, iPhone 16)
3. Press **Run** (⌘R)

The rest are simply for completeness.
TLDR ----- TLDR

# Run Bubbler on One Mac

This guide walks through running the full app locally on a single Mac: Postgres, the FastAPI backend, and the iOS Simulator.

The iOS client talks to `http://127.0.0.1:8000`, so the backend and simulator should run on the same machine.

## Prerequisites

Install these before you start:

| Tool | Purpose |
|------|---------|
| [Xcode](https://developer.apple.com/xcode/) | Build and run the iOS app in Simulator |
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | Local Postgres with pgvector |
| Python 3.12 | Backend runtime (`backend/Pipfile`) |
| [pipenv](https://pipenv.pypa.io/) | Python dependency management |

Quick install with Homebrew (optional):

```bash
brew install python@3.12 pipenv
brew install --cask docker
```

Open Docker Desktop once so the daemon is running before you start the backend script.

## 1. Clone and open the repo

```bash
git clone <your-repo-url> Bubbler
cd Bubbler
```

## 2. Start the backend

From the repo root, run:

```bash
chmod +x scripts/start_backend.sh   # first time only
./scripts/start_backend.sh --seed
```

What this script does:

1. Creates `backend/.env` from `backend/.env.example` if it does not exist
2. Starts a `pgvector/pgvector:pg16` Docker container on port `5433`
3. Applies `backend/app/db/schema.sql` on first run
4. Runs `pipenv install` in `backend/`
5. Seeds sample posts (with `--seed`)
6. Starts the API at `http://127.0.0.1:8000`

Leave this terminal open while you use the app.

### Verify the backend

In a second terminal:

```bash
curl http://127.0.0.1:8000/health
```

Expected response:

```json
{"status":"ok","database":"connected"}
```

You can also open [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs) to browse the API.

### Script options

```bash
./scripts/start_backend.sh              # start without seed data
./scripts/start_backend.sh --seed         # include sample posts
./scripts/start_backend.sh --rebuild-db   # wipe DB and reapply schema.sql
./scripts/start_backend.sh --no-docker  # use an existing Postgres instance
./scripts/start_backend.sh --help
```

If you use `--no-docker`, make sure Postgres has the `vector` extension and that `backend/.env` points at your database.

## 3. Open the iOS app in Xcode

```bash
open BubblerApp/BubblerApp.xcodeproj
```

In Xcode:

1. Select the **BubblerApp** scheme
2. Choose an **iPhone Simulator** (for example, iPhone 16)
3. Press **Run** (⌘R)

## 4. Sign in or create an account

The app opens on the login screen. A green **Backend connected** indicator means the simulator can reach the API.

1. Tap **Create account**
2. Enter a username, email, and password (password must be at least 5 characters)
3. Submit — you are signed in automatically after registration

The seeded `demo@bubbler.test` user from `scripts/seed_db.py` is for sample posts only; create your own account through the app.

## 5. Explore the app

After login, the default screen is the **Graph Feed**:

- **Like / Skip** — record interactions and advance through posts
- **Connected Choices** — tap a neighbor post to explore the graph
- **Load New Session** — pull a fresh set of posts
- **Settings (gear icon)** — open settings and sign out

From Settings:

| Screen | What it does |
|--------|----------------|
| **Bubble Sensitivity** | Tune diversity, randomness, topic lists, and feed weights (live API) |
| **Explore Other Bubbles** | Forces a diversified graph session (`?diversify=true`) to escape a topic region |
| **Classic Feed** | Scrollable feed view backed by `GET /feed/me` |

Some settings rows (profile, notifications, search) are still placeholder UI.

## 6. Stop everything

- **Backend:** press `Ctrl+C` in the terminal running `start_backend.sh`
- **Database:** `docker stop bubbler-db` (container is kept for next time)
- **Simulator:** stop the app from Xcode or quit Simulator

## Troubleshooting

### Login screen shows "Backend unavailable"

- Confirm the backend terminal is still running
- Run `curl http://127.0.0.1:8000/health`
- Restart with `./scripts/start_backend.sh --seed`

### Docker errors on startup

- Open Docker Desktop and wait until it reports running
- Check nothing else is using port `5433`: `lsof -i :5433`

### Graph feed is empty

- Restart the backend with `--seed` to insert sample posts
- Or create posts via the API after signing in (`POST /user/me/posts`)

### `pipenv: command not found`

```bash
pip install pipenv
# or
brew install pipenv
```

### Schema changed and the API errors on startup

The startup script only applies `schema.sql` on a fresh database. After pulling schema changes, rebuild and re-seed:

```bash
./scripts/start_backend.sh --rebuild-db --seed
```

This drops all tables in the local database and reapplies the current schema.

### First backend start is slow

The first run downloads the Postgres Docker image and Python packages (including `sentence-transformers`). Later starts are much faster.

## Daily workflow

Terminal 1:

```bash
./scripts/start_backend.sh
```

Xcode: **Run** on your preferred simulator.

That is the normal loop for day-to-day development on one Mac.
