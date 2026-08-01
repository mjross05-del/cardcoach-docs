# CardCoach Database Schema Handoff

Last updated: 2026-07-31 (stamp added per SYNC_PROTOCOL landing-date rule; content unchanged)

Generated on 2026-04-15 from the local Supabase database after applying all
repository migrations.

## Files

- `SCHEMA.md`: Human-readable schema reference generated from
  `supabase/migrations/`.
- `schema.public.sql`: Schema-only SQL dump of the Supabase `public` schema.
  This includes tables, views, functions, constraints, indexes, RLS policies,
  and grants. Located at `01_CORE/data/schema.public.sql` (recovered 2026-07-02).

## Commands Used

```sh
pnpm docs:schema
pnpm supabase:db-reset
npx supabase db dump --local --schema public -f docs/schema-handoff/2026-04-15/schema.public.sql
```

## Notes

- The SQL dump is schema-only; it does not include table data.
- The dump covers the `public` schema. Some foreign keys reference
  `auth.users`, but the Supabase-managed `auth` schema is not included.
- Do not send `supabase/seed.sql`, `.env` files, database URLs, or Supabase
  service keys unless the recipient is explicitly trusted to receive them.
- For a fully reproducible local database, pair this handoff with the repository
  migrations in `supabase/migrations/`.
