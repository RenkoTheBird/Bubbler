# Bubbler

Note — Docker and infra components are not yet included.

```
Bubbler/
│
├── README.md
├── .gitignore
│
├── BubblerApp/                   # Active SwiftUI iOS client (Xcode project)
│   ├── BubblerApp.xcodeproj
│   └── BubblerApp/
│       ├── BubblerAppApp.swift
│       ├── ContentView.swift
│       ├── AuthSession.swift
│       ├── APIClient.swift
│       ├── KeychainStore.swift
│       ├── LoginView.swift
│       ├── CreateAccountView.swift
│       ├── FeedView.swift
│       ├── ProfileView.swift
│       ├── SearchView.swift
│       ├── SettingsView.swift
│       ├── BubbleDetail.swift
│       ├── BubblerLogoView.swift
│       └── Assets.xcassets/
│
├── ios-app/                      # Feature-based iOS scaffold (in progress)
│   └── BubblerApp/
│       ├── App/
│       │   ├── BubblerApp.swift
│       │   ├── Components/
│       │   │   ├── BubbleView.swift
│       │   │   ├── PostView.swift
│       │   │   └── RootView.swift
│       │   ├── Features/
│       │   │   ├── Auth/
│       │   │   ├── Feed/
│       │   │   │   ├── FeedView.swift
│       │   │   │   └── FeedViewModel.swift
│       │   │   ├── Graph/
│       │   │   ├── Post/
│       │   │   └── Profile/
│       │   ├── Models/
│       │   │   ├── User.swift
│       │   │   ├── Post.swift
│       │   │   └── Topic.swift
│       │   ├── Services/
│       │   │   ├── APIClient.swift
│       │   │   └── AuthService.swift
│       │   ├── Utils/
│       │   │   └── Extensions.swift
│       │   └── Views/
│       │       └── PostView.swift
│       └── Assets/
│           └── bubbler 1.0.png
│
├── backend/                      # FastAPI backend
│   ├── main.py                   # FastAPI entrypoint
│   ├── config.py
│   ├── Pipfile
│   ├── Pipfile.lock
│   ├── .env.example
│   └── app/
│       ├── startup.py
│       ├── deps.py
│       │
│       ├── routes/
│       │   ├── auth.py
│       │   ├── feed.py
│       │   ├── graph.py          # DAG expansion endpoint
│       │   └── user.py
│       │
│       ├── db/
│       │   ├── schema.sql
│       │   ├── vector.py
│       │   └── migrations/       # (empty — Alembic planned)
│       │
│       ├── schemas/              # Pydantic schemas
│       │   ├── user.py
│       │   ├── post.py
│       │   └── edge.py
│       │
│       ├── services/             # Business logic
│       │   ├── auth.py
│       │   ├── post.py
│       │   ├── feed.py
│       │   ├── graph.py          # DAG logic
│       │   ├── user.py
│       │   └── interaction.py
│       │
│       ├── repositories/         # DB access layer
│       │   ├── auth_repo.py
│       │   ├── post_repo.py
│       │   ├── user_repo.py
│       │   ├── feed_repo.py
│       │   ├── interaction_repo.py
│       │   └── edge_builder_repo.py
│       │
│       └── ml/                   # Lightweight ML/NLP layer
│           ├── service.py
│           └── embeddings/
│               └── generate.py
│
├── scripts/                      # Dev scripts
│   ├── seed_db.py
│   └── run_checkpoints.py
│
└── docs/
    ├── api_contracts.md
    ├── roadmap.md
    └── TODO
```
