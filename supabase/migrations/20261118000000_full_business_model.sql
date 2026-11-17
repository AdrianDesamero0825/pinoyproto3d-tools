create extension if not exists pgcrypto;

create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  customer_name text not null,
  project_name text not null,
  customer_key text generated always as (lower(regexp_replace(trim(customer_name), '\s+', ' ', 'g'))) stored,
  project_key text generated always as (lower(regexp_replace(trim(project_name), '\s+', ' ', 'g'))) stored,
  status text not null default 'active' check (status in ('active', 'completed', 'archived')),
  created_by uuid references auth.users(id),
  updated_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (customer_key, project_key)
);

alter table public.quotations
  add column if not exists project_id uuid,
  add column if not exists revision_number integer not null default 1,
  add column if not exists status text not null default 'saved',
  add column if not exists total_amount numeric(12, 2) not null default 0,
  add column if not exists supersedes_id uuid;

alter table public.customer_trackers
  add column if not exists project_id uuid,
  add column if not exists customer_key text generated always as (lower(regexp_replace(trim(customer_name), '\s+', ' ', 'g'))) stored,
  add column if not exists project_key text generated always as (lower(regexp_replace(trim(project_name), '\s+', ' ', 'g'))) stored;

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete restrict,
  quotation_id uuid references public.quotations(id) on delete restrict,
  amount numeric(12, 2) not null check (amount > 0),
  payment_date date not null default current_date,
  payment_method text,
  reference_number text,
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.audit_events (
  id bigint generated always as identity primary key,
  entity_type text not null check (entity_type in ('project', 'quotation', 'tracker', 'payment')),
  entity_id uuid not null,
  action text not null check (action in ('created', 'updated', 'deleted', 'status_changed', 'payment_recorded')),
  changed_by uuid references auth.users(id),
  changed_at timestamptz not null default now(),
  changes jsonb not null default '{}'::jsonb
);

insert into public.projects (customer_name, project_name)
select customer_name, project_name
from (
  select distinct on (
    lower(regexp_replace(trim(customer_name), '\s+', ' ', 'g')),
    lower(regexp_replace(trim(project_name), '\s+', ' ', 'g'))
  )
    customer_name,
    project_name
  from (
    select customer_name, project_name
    from public.customer_trackers
    where nullif(trim(customer_name), '') is not null
      and nullif(trim(project_name), '') is not null
    union all
    select customer_name, project_name
    from public.quotations
    where nullif(trim(customer_name), '') is not null
      and nullif(trim(project_name), '') is not null
  ) source_rows
  order by
    lower(regexp_replace(trim(customer_name), '\s+', ' ', 'g')),
    lower(regexp_replace(trim(project_name), '\s+', ' ', 'g'))
) source_projects
on conflict (customer_key, project_key) do nothing;

update public.customer_trackers tracker
set project_id = project.id
from public.projects project
where tracker.project_id is null
  and project.customer_key = lower(regexp_replace(trim(tracker.customer_name), '\s+', ' ', 'g'))
  and project.project_key = lower(regexp_replace(trim(tracker.project_name), '\s+', ' ', 'g'));

update public.quotations quotation
set
  project_id = project.id,
  total_amount = coalesce((
    select sum(coalesce((item->>'qty')::numeric, 0) * coalesce((item->>'price')::numeric, 0))
    from jsonb_array_elements(coalesce(quotation.items, '[]'::jsonb)) item
  ), 0)
from public.projects project
where quotation.project_id is null
  and project.customer_key = lower(regexp_replace(trim(quotation.customer_name), '\s+', ' ', 'g'))
  and project.project_key = lower(regexp_replace(trim(quotation.project_name), '\s+', ' ', 'g'));

update public.quotations quotation
set revision_number = revisions.revision_number
from (
  select
    id,
    row_number() over (
      partition by project_id
      order by quotation_date asc nulls first, created_at asc nulls first, id
    )::integer as revision_number
  from public.quotations
  where project_id is not null
) revisions
where quotation.id = revisions.id;

alter table public.quotations
  add constraint quotations_project_id_fkey
  foreign key (project_id) references public.projects(id) on delete restrict;

alter table public.customer_trackers
  add constraint customer_trackers_project_id_fkey
  foreign key (project_id) references public.projects(id) on delete restrict;

create index if not exists quotations_project_id_idx on public.quotations(project_id, revision_number desc);
create index if not exists customer_trackers_project_id_idx on public.customer_trackers(project_id);
create index if not exists payments_project_id_idx on public.payments(project_id, payment_date desc);
create index if not exists audit_events_entity_idx on public.audit_events(entity_type, entity_id, changed_at desc);

create or replace function public.set_business_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists projects_set_updated_at on public.projects;
create trigger projects_set_updated_at
before update on public.projects
for each row execute function public.set_business_updated_at();

create or replace function public.write_business_audit_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  entity_type_value text;
  action_value text;
  entity_id_value uuid;
  old_data jsonb;
  new_data jsonb;
begin
  entity_type_value := case tg_table_name
    when 'projects' then 'project'
    when 'quotations' then 'quotation'
    when 'customer_trackers' then 'tracker'
    when 'payments' then 'payment'
  end;
  entity_id_value := case when tg_op = 'DELETE' then old.id else new.id end;
  old_data := case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) else '{}'::jsonb end;
  new_data := case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) else '{}'::jsonb end;
  action_value := case
    when tg_table_name = 'payments' and tg_op = 'INSERT' then 'payment_recorded'
    when tg_op = 'INSERT' then 'created'
    when tg_op = 'UPDATE'
      and tg_table_name in ('projects', 'quotations')
      and coalesce(old_data->>'status', '') is distinct from coalesce(new_data->>'status', '') then 'status_changed'
    when tg_op = 'UPDATE' then 'updated'
    else 'deleted'
  end;

  insert into public.audit_events (entity_type, entity_id, action, changed_by, changes)
  values (
    entity_type_value,
    entity_id_value,
    action_value,
    auth.uid(),
    jsonb_build_object('before', old_data, 'after', new_data)
  );
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

drop trigger if exists projects_audit on public.projects;
create trigger projects_audit
after insert or update or delete on public.projects
for each row execute function public.write_business_audit_event();

drop trigger if exists quotations_audit on public.quotations;
create trigger quotations_audit
after insert or update or delete on public.quotations
for each row execute function public.write_business_audit_event();

drop trigger if exists customer_trackers_audit on public.customer_trackers;
create trigger customer_trackers_audit
after insert or update or delete on public.customer_trackers
for each row execute function public.write_business_audit_event();

drop trigger if exists payments_audit on public.payments;
create trigger payments_audit
after insert or update or delete on public.payments
for each row execute function public.write_business_audit_event();

alter table public.projects enable row level security;
alter table public.payments enable row level security;
alter table public.audit_events enable row level security;
alter table public.quotations enable row level security;
alter table public.customer_trackers enable row level security;

drop policy if exists "Authenticated admins manage quotations" on public.quotations;
create policy "Authenticated admins manage quotations"
on public.quotations for all to authenticated
using (true) with check (true);

drop policy if exists "Authenticated admins manage customer trackers" on public.customer_trackers;
create policy "Authenticated admins manage customer trackers"
on public.customer_trackers for all to authenticated
using (true) with check (true);

drop policy if exists "Authenticated admins manage projects" on public.projects;
create policy "Authenticated admins manage projects"
on public.projects for all to authenticated
using (true) with check (true);

drop policy if exists "Authenticated admins manage payments" on public.payments;
create policy "Authenticated admins manage payments"
on public.payments for all to authenticated
using (true) with check (true);

drop policy if exists "Authenticated admins read audit events" on public.audit_events;
create policy "Authenticated admins read audit events"
on public.audit_events for select to authenticated
using (true);
