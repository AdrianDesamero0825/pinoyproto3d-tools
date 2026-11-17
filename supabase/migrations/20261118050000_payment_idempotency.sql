create unique index if not exists payments_tracker_total_upsert_unique
  on public.payments(source_tracker_id, source_paid_total);

notify pgrst, 'reload schema';
