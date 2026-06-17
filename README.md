# Bubbler

Note -- currently Docker components are left out

bubbler/
│
├── README.md  
├── .gitignore  
├── docker-compose.yml        # (optional)  
│  
├── ios-app/                  # SwiftUI iOS client  
│   ├── BubblerApp.xcodeproj  
│   ├── BubblerApp/  
│   │   ├── App/  
│   │   │   └── BubblerApp.swift  
│   │   │  
│   │   ├── Features/         # Feature-based organization  
│   │   │   ├── Auth/  
│   │   │   ├── Feed/  
│   │   │   ├── Graph/  
│   │   │   ├── Post/  
│   │   │   └── Profile/  
│   │   │  
│   │   ├── Components/       # Reusable UI    
│   │   │   ├── PostView.swift  
│   │   │   └── BubbleView.swift  
│   │   │  
│   │   ├── Services/  
│   │   │   ├── APIClient.swift  
│   │   │   └── AuthService.swift  
│   │   │  
│   │   ├── Models/  
│   │   │   ├── User.swift  
│   │   │   ├── Post.swift  
│   │   │   └── Topic.swift  
│   │   │  
│   │   └── Utils/  
│   │       └── Extensions.swift  
│   │  
│   └── Resources/  
│       └── Assets.xcassets  
│  
├── backend/                  # FastAPI backend  
│   ├── app/  
│   │   ├── main.py           # FastAPI entrypoint  
│   │   │  
│   │   ├── api/              # Route layer  
│   │   │   ├── deps.py  
│   │   │   ├── routes/  
│   │   │   │   ├── auth.py  
│   │   │   │   ├── posts.py  
│   │   │   │   ├── feed.py  
│   │   │   │   ├── graph.py   # DAG expansion endpoint  
│   │   │   │   └── users.py  
│   │   │  
│   │   ├── core/             # Config & settings  
│   │   │   ├── config.py  
│   │   │   └── security.py  
│   │   │  
│   │   ├── db/  
│   │   │   ├── session.py  
│   │   │   ├── base.py  
│   │   │   └── migrations/   # Alembic  
│   │   │  
│   │   ├── models/           # DB models  
│   │   │   ├── user.py  
│   │   │   ├── post.py  
│   │   │   ├── topic.py  
│   │   │   ├── interaction.py  
│   │   │   ├── edge.py  
│   │   │   └── user_profile.py  
│   │   │  
│   │   ├── schemas/          # Pydantic schemas  
│   │   │   ├── user.py  
│   │   │   ├── post.py  
│   │   │   ├── feed.py  
│   │   │   └── graph.py  
│   │   │  
│   │   ├── services/         # Business logic  
│   │   │   ├── post_service.py  
│   │   │   ├── feed_service.py  
│   │   │   ├── graph_service.py   # DAG logic  
│   │   │   ├── similarity_service.py  
│   │   │   └── user_service.py  
│   │   │  
│   │   ├── repositories/     # DB access layer  
│   │   │   ├── post_repo.py  
│   │   │   ├── user_repo.py  
│   │   │   └── interaction_repo.py  
│   │   │  
│   │   └── utils/  
│   │       └── embeddings.py  
│   │  
│   ├── tests/  
│   │   └── test_posts.py  
│   │  
│   ├── requirements.txt  
│   └── alembic.ini  
│  
├── ml/                       # Lightweight ML/NLP layer  
│   ├── embeddings/  
│   │   ├── model.py          # InstructorXL wrapper  
│   │   └── generate.py  
│   │  
│   ├── similarity/  
│   │   ├── cosine.py  
│   │   └── search.py         # pgvector queries  
│   │  
│   └── service.py            # Optional microservice (FastAPI)  
│  
├── scripts/                  # Dev scripts  
│   ├── seed_db.py   
│   └── create_embeddings.py  
│  
└── infra/                    # Optional but useful early  
    ├── docker/  
    │   ├── backend.Dockerfile  
    │   └── ml.Dockerfile  
    │  
    └── terraform/ (optional later)  