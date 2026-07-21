# System Architecture

```mermaid
%%{init: {"flowchart": {"curve": "linear", "nodeSpacing": 18, "rankSpacing": 22}, "themeVariables": {"fontSize": "12px"}}}%%
flowchart TB
    App["SwiftUI iOS App"]
    API["FastAPI API"]

    subgraph Core["Application Services"]
        direction LR
        Feed["Feed + Graph"]
        Search["Search"]
        Account["Auth + User"]
    end

    Repos["Repository Layer"]
    DB[("Postgres<br/>pgvector + tsvector")]
    ML["MiniLM<br/>Embeddings"]
    OAuth["OAuth + Keychain"]

    App -->|"HTTPS / JSON"| API
    App -.-> OAuth
    API --> Feed
    API --> Search
    API --> Account
    Feed --> Repos
    Search --> Repos
    Account --> Repos
    Feed <--> ML
    Search <--> ML
    Repos --> DB
```

The iOS client calls the FastAPI backend, whose services contain the application logic.
Repositories isolate database access, while MiniLM embeddings and PostgreSQL extensions
support recommendation, graph traversal, and hybrid search.
