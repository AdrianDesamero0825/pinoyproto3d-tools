# Supabase migrations

Apply migrations in filename order with the Supabase CLI or the SQL editor.

## Full business model

Apply `migrations/20261118000000_full_business_model.sql` once. It:

- Creates stable `projects` records and backfills them from existing quotations and trackers.
- Adds project links, quotation status, revision numbers, totals, and superseded-quotation links.
- Creates a `payments` ledger without removing the existing tracker payment summary.
- Creates `audit_events` and database triggers for projects, quotations, trackers, and payments.
- Enables authenticated-only access to the new tables.

The migration is designed to preserve existing records. Review the generated project list before deleting or merging any duplicates.

```powershell
npx supabase db push
```

Do not run the migration repeatedly by copying fragments into production. Use the migration history so it is applied exactly once.
