# Data Retention Schedule

Internal retention policy for Bubbler (beta). Counsel should review before production. Public summary belongs in the Privacy Policy (roadmap L1).

Related: [`privacy_legal.md`](privacy_legal.md) §10, [`breach_playbook.md`](breach_playbook.md), [`roadmap.md`](roadmap.md) L10, [`backend/config.py`](../backend/config.py), [`backend/app/db/schema.sql`](../backend/app/db/schema.sql).

---

## Schedule (beta defaults)

| Data | Table(s) | Retention | Mechanism |
| --- | --- | --- | --- |
| Accounts, prefs, blocks (live) | `users`, `user_profiles`, `user_topic_prefs`, `user_blocks` | Life of account | `DELETE /user/me` cascades after tombstone write |
| Deleted-account identity | `deleted_accounts` | **90 days** after `deleted_at` | Snapshot on delete (`DELETED_ACCOUNT_RETENTION_DAYS`); skip `legal_hold` |
| Posts, topics, edges | `posts`, `post_topics`, `edges`, `media` | Until user deletes or account erasure | FK `ON DELETE CASCADE` |
| Interactions — feed preferences | `interactions` (`type = 'preference'`) | Life of account | Not auto-purged (slider state) |
| Interactions — explore/skip + view-time | `interactions` (`type IN ('explore', 'skip')`) | **270 days** rolling | Scheduled job (`INTERACTIONS_RETENTION_DAYS`) |
| Topic training events | `topic_training_events` | Anonymize after **180 days**; delete anonymized after **365 days** | Job sets `user_id = NULL`, then deletes |
| Report / export limit counters | `reporter_daily_limits`, `user_report_limits`, `user_data_export_limits` | **90 days** | Scheduled `DELETE` by `day` |
| Content reports — open / in review | `content_reports` | Until resolved + counsel rules | Never auto-purged |
| Content reports — closed, no hold | `content_reports` (`resolved` / `dismissed`, `legal_hold = false`) | **730 days** after `resolved_at` | Scheduled job |
| Content reports — legal hold / severe-illegal | `content_reports` | Counsel-defined | `legal_hold = true` or manual policy |
| App / server logs | Hosting log sink | **90 days** | Platform config (`LOG_RETENTION_DAYS`) |
| DB backups (Supabase) | Backups / PITR | **30 days** | Supabase project settings (`BACKUP_RETENTION_DAYS`) |

Account erasure: `DELETE /user/me` writes an identity tombstone to `deleted_accounts` (no password), then hard-deletes the live `users` row. Email and username unique indexes stay on `users` only, so they can be reused immediately. `content_reports` use `ON DELETE SET NULL` on user/post FKs so tickets and snapshots can outlive deleted accounts. Disclose tombstone TTL, ticket leftovers, and backups in Delete Account copy and Privacy Policy.

---

## Schema changes (implemented)

Reference schema updates in `backend/app/db/schema.sql`:

### `deleted_accounts`

- Identity copy written in the same transaction as `DELETE FROM users` (`user_id`, `username`, `email`, `date_of_birth`, `role`, `created_at`, `deleted_at`, `deletion_source`, `legal_hold`).
- **No** password hash. **No** FK to `users`. **No** unique constraint on email or username (erasure-friendly reuse).
- `legal_hold` is set at delete time when the user has open/`in_review` tickets, `legal_hold` tickets, or `reason = 'illegal_content'`.
- Partial index `deleted_accounts_purge_candidates_idx` on `(deleted_at)` where `legal_hold = FALSE`.

### `topic_training_events`

- `user_id` is **nullable** so retention can anonymize (`UPDATE … SET user_id = NULL`) while keeping `post_id`, `topic_name`, and `action` for model training.
- Index `topic_training_events_created_at_idx` supports age-based anonymize/delete scans.

### `interactions`

- Partial index `interactions_explore_skip_created_at_idx` on `(created_at)` where `type IN ('explore', 'skip')` for efficient rolling purges. Feed preferences are excluded.

### `content_reports`

- `legal_hold BOOLEAN NOT NULL DEFAULT FALSE` — when true, ticket must not be auto-purged.
- `resolved_at TIMESTAMP` — set when status becomes `resolved` or `dismissed`; purge eligibility uses `COALESCE(resolved_at, created_at)`.
- Partial index `content_reports_purge_candidates_idx` on closed, non-hold tickets.

### Existing databases

Apply equivalent `ALTER TABLE` / `CREATE INDEX` statements before running a retention job on a live database. There is no migration runner in-repo; `schema.sql` is the reference.

---

## Config (implemented)

Optional env vars in `backend/config.py` (`my_env_vars.retention`). Defaults match the beta table above.

| Env var | Default | Purpose |
| --- | --- | --- |
| `INTERACTIONS_RETENTION_DAYS` | 270 | Purge explore/skip older than N days |
| `TRAINING_EVENTS_ANONYMIZE_AFTER_DAYS` | 180 | Clear `user_id` on older training rows |
| `TRAINING_EVENTS_DELETE_AFTER_DAYS` | 365 | Delete anonymized training rows |
| `LIMIT_TABLE_RETENTION_DAYS` | 90 | Purge old limit-table rows |
| `CLOSED_REPORT_RETENTION_DAYS` | 730 | Purge closed, non-hold reports |
| `DELETED_ACCOUNT_RETENTION_DAYS` | 90 | Purge identity tombstones |
| `LOG_RETENTION_DAYS` | 90 | Documented ops target (hosting) |
| `BACKUP_RETENTION_DAYS` | 30 | Documented ops target (Supabase) |

---

## What remains (L10)

Policy and schema/config groundwork is in place. Still required for a complete retention program:

### Engineering

- [x] **`run_retention.py`** — `backend/scripts/run_retention.py` with `--dry-run` and batched purges via `RetentionService` / `RetentionRepository`.
- [x] **Tests** — `backend/tests/test_retention.py` (repo/service dry-run, batching, schema reference guards, `resolved_at` SQL, deleted-account tombstone).
- [x] **`resolved_at` population** — set on `resolved` / `dismissed`; cleared on reopen (`report_repo.update_staff_report_status`).
- [x] **Deleted-account tombstone** — `deleted_accounts` snapshot on `DELETE /user/me`; purge after `DELETED_ACCOUNT_RETENTION_DAYS`.
- [x] **Admin legal hold** — staff API/UI to set `content_reports.legal_hold` and matching `deleted_accounts.legal_hold` (required before enabling report purge in production).
- [x] **Severe-illegal policy in job** — auto-purge skips `reason = 'illegal_content'` until counsel signs off (L11).
- [x] **Delete Account copy** — state that an identity record may be kept up to 90 days, and that moderation tickets and backups may retain data longer (L9 UX).
- [ ] **Media object storage** — when uploads ship (F6), delete blobs when `media` rows are removed; orphan cleanup job.

### Ops / legal

- [ ] **Supabase backup TTL** — set to ~30 days; record in ROPA.
- [ ] **Log retention** — configure 30–90 days on the hosting log sink.
- [ ] **Privacy Policy summary** — publish retention periods for users (L1).
- [ ] **Breach playbook** — scaffold in [`breach_playbook.md`](breach_playbook.md); fill contacts, counsel review, tabletop, and Privacy Policy paragraph still open.
- [ ] **Counsel review** — especially closed-report retention, CSAM/legal-hold workflow (L11).

### Roadmap

L10 stays **partially complete**: schedule documented, schema/config ready, retention job, identity tombstone, `resolved_at`, and staff legal-hold wired; breach playbook scaffolded; ops/legal completion items still open (see [`breach_playbook.md`](breach_playbook.md) §12).

### Running the job

From `backend/`:

```bash
pipenv run python scripts/run_retention.py --dry-run
pipenv run python scripts/run_retention.py
```

Schedule nightly on your host (cron, Render/Fly scheduled task, etc.).
