Frontend should return something like:

{
  "feed_preset": "stay_in_lane",
  "topic_composition": {
    "similar": 0.55,
    "opposite": 0.15,
    "surprise": 0.30
  },
  "post_composition": {
    "similar": 0.55,
    "opposite": 0.15,
    "surprise": 0.30
  },
  "topic_preferences": [
    {"topic": "technology", "preference_type": "preferred"},
    {"topic": "politics", "preference_type": "blacklisted"}
  ],
  "use_view_time": false,
  "view_time_weight": 0.1,
  "use_recency": false,
  "ai_topic_detection": false
}

Preset IDs: `stay_in_lane`, `cross_pollinate`, `wild_walk`, `custom`. When `feed_preset` is not `custom`, the server normalizes `topic_composition` and `post_composition` to the preset values on save.

**New accounts:** `POST /auth/register` inserts `user_profiles` in the same transaction with conservative defaults—`stay_in_lane`, empty `topic_preferences`, and `use_recency`, `use_view_time`, and `ai_topic_detection` all `false`. See [`moderation.md`](moderation.md) § Default protections.

Graph session (`GET /feed/me/session?diversify=true|false`) returns:

{
  "posts": [ /* Post objects */ ],
  "seed_strategy": "soft_prior | diversify | random | …",
  "diversify": false
}

Hybrid search (`GET /search?q=...`) returns:

{
  "query": "space",
  "exact_matches": [ /* Post objects — tsvector keyword, topic, or username hits */ ],
  "related": [ /* Post objects — embedding-similar and light graph neighbors */ ]
}

Notes:
- `exact_matches` are ranked by Postgres `ts_rank_cd` plus topic/username boosts (no opposite/random feed mix).
- `related` requires embedding cosine similarity ≥ 0.35, excludes exact-match IDs, and soft-filters blacklisted topics.
- Known topic queries (for example `science`) boost same-topic exact matches.

---

## Reports (moderation Phase 0 / roadmap L6)

Auth: Bearer JWT on all routes below. Staff routes additionally require `users.role = staff` (live DB check → 403 otherwise).

### Create report — `POST /user/me/reports` → 201

Request:

```json
{
  "post_id": "uuid",
  "reason": "illegal_content | severe_violence | non_consensual_sexual_content | harassment | spam | other",
  "details": "optional plain-text note, ≤ 2000 chars"
}
```

Reporter-facing response (no snapshots; no other reporters’ tickets):

```json
{
  "id": "uuid",
  "post_id": "uuid",
  "reason": "spam",
  "details": "looks automated",
  "status": "open",
  "created_at": "2026-08-20T15:00:00Z"
}
```

Errors:
- `400` — reporting your own post
- `404` — post not found
- `409` — you already have an **open** report on this post (does not reveal other reporters)
- `422` — unknown reason or `details` over 2000 chars
- `429` — rate limited (max 20 reports/reporter/UTC day **and** max 1 report/reporter→author/UTC day)

Notes:
- `details` are stripped of control characters; blank → `null`.
- Filing a report only opens a queue ticket — no auto-hide / auto-delete (enforcement is L7).
- `illegal_content` is the severe-illegal / CSAM isolation bucket (escalation procedure is L11).
- See [`moderation.md`](moderation.md) “Reporter path” for the full safety guarantees.

### Staff queue — `GET /admin/reports?status=open&reason=`

Query:
- `status` — required filter; default `open` (`open` | `in_review` | `resolved` | `dismissed`)
- `reason` — optional; use `illegal_content` to isolate the severe-illegal queue

Response: array of staff tickets (frozen text snapshots):

```json
[
  {
    "id": "uuid",
    "reporter_id": 3,
    "post_id": "uuid",
    "reported_user_id": 9,
    "reason": "illegal_content",
    "details": "optional note",
    "status": "open",
    "content_snapshot": "Buy followers now",
    "topic_snapshot": "business",
    "author_username_snapshot": "spammer",
    "legal_hold": false,
    "created_at": "2026-08-20T15:00:00Z"
  }
]
```

### Staff detail — `GET /admin/reports/{report_id}`

Same staff ticket object as above. `404` if missing.

### Triage status — `PATCH /admin/reports/{report_id}`

Request:

```json
{ "status": "in_review | resolved | dismissed | open" }
```

Response: updated staff ticket. Status changes do **not** remove or restrict the post (L7).

### Legal hold — `PATCH /admin/reports/{report_id}/legal-hold`

Request:

```json
{ "legal_hold": true }
```

Response: updated staff ticket. When toggled, matching `deleted_accounts` tombstones for the reporter and reported user are recomputed so retention purge stays consistent.
