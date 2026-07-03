# Bubbler

Note — Docker and infra components are not yet included.

```
Bubbler/
│
├── README.md
├── .gitignore
│
├── BubblerApp/                   # SwiftUI iOS client  
│   ├── BubblerApp.xcodeproj
│   └── BubblerApp/
│       ├── App/
│       │   └── BubblerAppApp.swift
│       ├── Navigation/
│       │   └── ContentView.swift
│       ├── Core/
│       │   ├── APIClient.swift
│       │   ├── AuthSession.swift
│       │   ├── BackendConnection.swift
│       │   └── KeychainStore.swift
│       ├── Models/
│       │   ├── Post.swift
│       │   ├── Topic.swift
│       │   └── User.swift
│       ├── Components/
│       │   ├── BubblerLogoView.swift
│       │   └── PostCardView.swift
│       ├── Features/
│       │   ├── Auth/
│       │   │   ├── CreateAccountView.swift
│       │   │   └── LoginView.swift
│       │   ├── Feed/
│       │   │   ├── FeedView.swift
│       │   │   └── FeedViewModel.swift
│       │   ├── Profile/
│       │   │   ├── BubbleDetail.swift
│       │   │   └── ProfileView.swift
│       │   ├── Search/
│       │   │   └── SearchView.swift
│       │   └── Settings/
│       │       └── SettingsView.swift
│       └── Assets.xcassets/
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
│       │   └── migrations/       # (empty for now)
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
