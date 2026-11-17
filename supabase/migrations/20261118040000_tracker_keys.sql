alter table public.customer_trackers
  add column if not exists customer_key text generated always as (
    lower(regexp_replace(trim(customer_name), '\s+', ' ', 'g'))
  ) stored,
  add column if not exists project_key text generated always as (
    lower(regexp_replace(trim(project_name), '\s+', ' ', 'g'))
  ) stored;

create index if not exists customer_trackers_business_key_idx
  on public.customer_trackers(customer_key, project_key, created_at desc);
