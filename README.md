# Bubbler

## Personalized and In-Control Social Media

Bringing the user back in control.

An algorithm built for the user, not for selling data.

Customize exactly what you see, when, and how.

A new GraphFeedView makes browsing exciting again and makes discovery real.

## What is Bubbler?

Bubbler is a new app designed to change the way people interact with social media. 
Instead of a traditional FeedView with linear scrolling that does not require any
deliberate action on the user's part, Bubbler presents a GraphFeedView that allows
the user to explore social media in a unique "path", where "Bubbles" are presented based on their topic. Selecting a "Bubble" pulls up a new post; the user can select it and repeat the path process or go back and select another Bubble. They can also refresh Bubbles entirely. 

The user can prefer post topics (to see them more often) and blacklist them 
(to not see them at all). They can also adjust diversity + randomness of every Bubble, or identify whether they want new candidate Bubbles to be selected based on similarity, oppositeness, graph (generated neighbors, see Technical Details), or randomness (after candidates are selected instead).

There is also a search function available (using tsvector), a profile view showing the
user's interaction history and posts, and a settings screen allowing users to adjust 
authentication settings (including account delete) along with the preferences described.

## Technical Details

Authentication is implemented here using OAuth and bcrypt; keychains are stored using
Swift libraries.

Similarity is calculated using cosine similarity; we use Postgres's pgvector extension for this. (The same is true of opposite). Random is calculated using a TABLESAMPLE. Graph
comes out of candidate searching; when DFS is run on the current post's neighbors to get
candidates, some of these are automatically chosen as candidates instead of digging deeper.

The user has the ability to adjust those "strategy weights" for that candidate selection,
which is how the algorithmic preferences are implemented. Preferred topics are also factored
into this. (If a candidate is in the blacklisted topics list it is skipped and moved on.)

Diversity controls how much the Bubble should stay on one topic and determines how many
posts of one topic can show up at once.

Search is implemented using tsvector.

## Tech Stack

Frontend: Swift
Backend: FastAPI
Database: Postgres/pgvector/Supabase
Authentication: OAuth
ML: HuggingFace (all-MiniLM-L6-v2)

Frontend designs were made in Figma.

## AI Disclaimer

AI was used in the development of this codebase in the following ways:
- Initial planning and file structure
- Learning about FastAPI and Swift
- Wiring frontend and backend
- Many Swift pages, such as the Models and navigation
- More complicated feed repositories
- FeedService (services/feed.py)
- Scripts and documentation
- DFS logic
- The following features:
    - Search 
    - Graph Feed
    - Preferring/blacklisting topics
    - Preserving frontend states
    - Showing posts in the profile

AI was NOT used for:
- The fundamental Bubbler concept
- Backend design, wiring, and auth routes
- Authentication system
- Fundamental frontend designs
- Most settings pages (including Recommendation Preferences)
- Initial repositories
- Services (except Feed)
- MainTabView
- ML implementation
- Strategy service and scoring design
- Testing each component painstakingly!

## Filemap

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
│       │   ├── KeychainStore.swift
│       │   └── LikedPostsStore.swift
│       ├── Models/
│       │   ├── GraphFeedNode.swift
│       │   ├── Interaction.swift
│       │   ├── KnownTopics.swift
│       │   ├── Post.swift
│       │   ├── PublicUser.swift
│       │   ├── SearchResponse.swift
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
│       │   │   ├── BubbleTrailView.swift
│       │   │   ├── ProfileView.swift
│       │   │   ├── ProfileViewModel.swift
│       │   │   └── UserProfileView.swift
│       │   ├── Search/
│       │   │   ├── SearchView.swift
│       │   │   └── SearchViewModel.swift
│       │   └── Settings/
│       │       ├── DeleteAccountView.swift
│       │       ├── DeleteAccountViewModel.swift
│       │       ├── EmailSettingsView.swift
│       │       ├── EmailSettingsViewModel.swift
│       │       ├── PasswordSecurityView.swift
│       │       ├── PasswordSecurityViewModel.swift
│       │       ├── PreferencesSettingsView.swift
│       │       ├── PreferencesSettingsViewModel.swift
│       │       ├── ProfileInformationView.swift
│       │       ├── ProfileInformationViewModel.swift
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
│       │   ├── search.py         # Hybrid keyword + semantic search
│       │   ├── system.py
│       │   └── user.py           # Posts, topics, preferences, interactions
│       │
│       ├── db/
│       │   ├── schema.sql        # users, topics, posts, post_topics, …
│       │   ├── conn.py
│       │   ├── datetime_utils.py
│       │   ├── topics.py         # KNOWN_TOPICS curated list
│       │   ├── feed_sql.py       # posts_with_topic view helpers
│       │   ├── vector.py
│       │   └── jsonb.py
│       │
│       ├── schemas/              # Pydantic schemas
│       │   ├── user.py
│       │   ├── post.py
│       │   ├── search.py
│       │   └── edge.py
│       │
│       ├── services/             # Business logic
│       │   ├── auth.py
│       │   ├── post.py
│       │   ├── feed.py
│       │   ├── graph.py
│       │   ├── search.py
│       │   ├── user.py
│       │   ├── interaction.py
│       │   └── topic_detection.py
│       │
│       ├── repositories/         # DB access layer
│       │   ├── auth_repo.py
│       │   ├── post_repo.py
│       │   ├── search_repo.py
│       │   ├── user_repo.py
│       │   ├── feed_repo.py
│       │   ├── interaction_repo.py
│       │   └── edge_builder_repo.py
│       │
│       └── ml/                   # Lightweight ML/NLP layer
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
    ├── run_on_mac.md
    └── TODO
```
