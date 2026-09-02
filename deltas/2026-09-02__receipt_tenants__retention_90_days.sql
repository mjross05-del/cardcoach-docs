-- 2026-09-02 — receipt.tenants: retention_days 90 for the first-party tenant (RCPT-011).
-- Decision: Mike, 2026-09-02 ("90 days"). Applied inside migration 20260902163813
-- (rcpt_011_receipt_retention_90_days) via MCP apply_migration, 16:38 UTC.
-- Rule 9: snapshot receipt.tenants_snapshot_20260902 (1 row, RLS on, API roles revoked) taken
-- in the same transaction; post-state guard asserted exactly one row with slug = 'cardcoach'
-- and retention_days = 90. Rows affected: 1. This file is the record, not a script to re-run.
--
-- Effect: receipt.purge_expired(500) (scheduled 03:10 UTC daily by the same migration) hard-
-- deletes receipts older than 90 days and queues their images; receipt-purge-worker
-- (03:20 UTC) deletes the objects. First deletions fall due 2026-11-24 (oldest receipt
-- 2026-08-26).

update receipt.tenants
   set retention_days = 90
 where slug = 'cardcoach'
   and retention_days is null;
-- rollback: update receipt.tenants set retention_days = null where slug = 'cardcoach';
