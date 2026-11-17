# Supabase migrations

Apply migrations in filename order with the Supabase CLI or the SQL editor.

## Full business model

Apply `migrations/20261118000000_full_business_model.sql` once. It:

- Creates stable `projects` records and backfills them from existing quotations and trackers.
- Adds project links, quotation status, revision numbers, totals, and superseded-quotation links.
- Creates a `payments` ledger without removing the existing tracker payment summary.
- Creates `audit_events` and database triggers for projects, quotations, trackers, and payments.
- Enables authenticated-only access to the new tables.

## Enterprise hardening

Apply `migrations/20261118010000_enterprise_hardening.sql` after the business-model migration. It:

- Adds `team_members` roles (`owner`, `admin`, `operator`, `viewer`) and restricts business data to active members.
- Records actor and update timestamps at the database layer instead of trusting browser input.
- Adds quotation revision integrity and idempotent payment-source keys.
- Redacts model-file URLs and large quotation payloads from audit snapshots.
- Converts customer model files to private storage with expiring signed links.

Existing authenticated users are seeded as owners during this transition. Review `team_members` afterward and reduce each user's role to the minimum required access.

## Admin-only updates

Apply `migrations/20261118020000_admin_only_updates.sql` after the enterprise-hardening migration. Operators can still create quotations, trackers, projects, and payment entries, but only owners and admins can update existing quotations, trackers, or projects. The customer tracker also hides edit/update/delete controls for non-admin users.

Apply `migrations/20261118030000_quotation_sync_rpc.sql` afterward. The quotation maker uses this controlled function to create or link the project and tracker and save quotation revisions. This automatic workflow synchronization is permitted for operators; manual record updates remain admin-only.

Apply `migrations/20261118040000_tracker_keys.sql` and `migrations/20261118050000_payment_idempotency.sql` after the workflow RPC. They add the tracker business-key columns required by synchronization and a PostgREST-compatible unique payment key required for idempotent payment upserts.

Apply `migrations/20261118060000_remove_legacy_public_policies.sql` after the payment migration. It removes legacy anonymous quotation and tracker policies that would otherwise combine with the enterprise policies through PostgreSQL's permissive OR behavior. After this migration, unauthenticated users cannot read or create business records.

Apply `migrations/20261118070000_atomic_quotation_workflow.sql` last. The quotation maker sends the quotation payload to one transactional security-definer function that creates the quotation, project, tracker, and revision linkage together. Any failure rolls back the complete workflow instead of leaving an orphan quotation. The previous two-step synchronization RPC is no longer executable by authenticated clients.

The migration is designed to preserve existing records. Review the generated project list before deleting or merging any duplicates.

```powershell
npx supabase db push
```

Do not run the migration repeatedly by copying fragments into production. Use the migration history so it is applied exactly once.
