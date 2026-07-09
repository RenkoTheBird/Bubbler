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
│       │   ├── ContentView.swift
│       │   └── MainTabView.swift
│       ├── Core/
│       │   ├── APIClient.swift
│       │   ├── AuthSession.swift
│       │   ├── BackendConnection.swift
│       │   └── KeychainStore.swift
│       ├── Models/
│       │   ├── GraphFeedNode.swift
│       │   ├── KnownTopics.swift
│       │   ├── Post.swift
│       │   ├── Topic.swift
│       │   ├── TopicPreferenceList.swift
│       │   ├── User.swift
│       │   └── UserPreferences.swift
│       ├── Components/
│       │   ├── BubblerLogoView.swift
│       │   ├── PostCardView.swift
│       │   ├── PreferenceSliderRow.swift
│       │   ├── PreferenceTopicsEditor.swift
│       │   └── TopicPicker.swift
│       ├── Features/
│       │   ├── Auth/
│       │   │   ├── CreateAccountView.swift
│       │   │   └── LoginView.swift
│       │   ├── Feed/
│       │   │   ├── FeedView.swift
│       │   │   └── FeedViewModel.swift
│       │   ├── Graph/
│       │   │   ├── GraphFeedView.swift
│       │   │   └── GraphFeedViewModel.swift
│       │   ├── Post/
│       │   │   ├── CreatePostView.swift
│       │   │   └── CreatePostViewModel.swift
│       │   ├── Profile/
│       │   │   ├── BubbleDetail.swift
│       │   │   ├── ProfileView.swift
│       │   │   └── UserProfileView.swift
│       │   ├── Search/
│       │   │   └── SearchView.swift
│       │   └── Settings/
│       │       ├── PreferencesSettingsView.swift
│       │       ├── PreferencesSettingsViewModel.swift
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
│       │   ├── graph.py          # Graph expansion endpoint
│       │   ├── system.py
│       │   └── user.py           # Posts, topics, preferences, interactions
│       │
│       ├── db/
│       │   ├── schema.sql        # users, topics, posts, post_topics, …
│       │   ├── topics.py         # KNOWN_TOPICS curated list
│       │   ├── feed_sql.py       # posts_with_topic view helpers
│       │   ├── vector.py
│       │   └── jsonb.py
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
│       │   ├── graph.py
│       │   ├── user.py
│       │   ├── interaction.py
│       │   └── topic_detection.py
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
│   ├── seed_db.py                # Seed topics, post_topics, edges
│   ├── run_checkpoints.py        # Phases 0–7 smoke/regression checks
│   └── start_backend.sh
│
└── docs/
    ├── api_contracts.md
    ├── roadmap.md
    ├── run_on_mac.md
    └── TODO
```
