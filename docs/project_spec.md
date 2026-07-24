# Project Specification

Bubbler is a **user-controlled social exploration app**: posts live on a directed topic/semantic graph, and the person browsing chooses the next hop instead of scrolling a opaque ranked list.

```mermaid
%%{init: {"flowchart": {"curve": "linear", "nodeSpacing": 28, "rankSpacing": 36}, "themeVariables": {"fontSize": "12px"}}}%%
flowchart TB
    subgraph Who["For who"]
        User["People who want deliberate control<br/>over what they see, when, and how"]
        NotWho["Not a growth/ad platform<br/>Not a content-moderation product"]
        User -.-> NotWho
    end

    subgraph Does["What it does now"]
        Graph["GraphFeedView<br/>current post + up to 4 next Bubbles"]
        Prefs["Preferences<br/>prefer / blacklist topics<br/>strategy weights · diversity · randomness"]
        Auth["Auth + account<br/>OAuth · bcrypt · Keychain"]
        Search["Hybrid search<br/>tsvector + embeddings"]
        Profile["Profile<br/>posts + interaction trail"]
        Ranked["Ranked feed session<br/>strategy-seeded candidates"]
    end

    subgraph Bound["Boundaries of current work"]
        In["In scope"]
        Out["Out of scope · deferred"]

        In --> Stack["SwiftUI iOS client<br/>FastAPI · Postgres/pgvector/Supabase<br/>MiniLM embeddings"]
        In --> Core["Graph walk · preference ranking<br/>posts · topics · interactions<br/>settings · search · profile"]
        In --> Eval["Dev scripts · checkpoints<br/>preference-impact experiments"]

        Out --> Social["Follows · comments · block users<br/>media · bios · forgot password"]
        Out --> Later["In-graph search · preference stats UI<br/>stronger topic ML · Roundabout<br/>bubble identity watermark"]
    end

    User --> Graph
    User --> Prefs
    Graph --> Prefs
    Prefs --> Ranked
    Graph --> Bound
    Prefs --> Bound
```

## One-line scope

| Axis | Current answer |
| --- | --- |
| **Does** | Lets a signed-in user explore posts as a graph of Bubbles, shaped by explicit preference and strategy controls, plus search and profile. |
| **For who** | End users who want an algorithm built for them—not for engagement farming or selling attention. |
| **Boundary** | Vertical slice of graph feed + preferences + auth/search/profile on the stack above. Social network features, media, and deeper analytics are deferred (see [`TODO`](TODO)). |

## Related docs

- [`architecture.md`](architecture.md) — graph model, ranking, request flow
- [`api_contracts.md`](api_contracts.md) — preference and feed/search payloads
- [`TODO`](TODO) — immediate testing, pre-production, and future work
