create table if not exists public.team_members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('owner', 'admin', 'operator', 'viewer')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.team_members (user_id, role)
select id, 'owner'
from auth.users
on conflict (user_id) do nothing;

create or replace function public.is_business_member()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.team_members
    where user_id = auth.uid()
      and active
  );
$$;

create or replace function public.is_business_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.team_members
    where user_id = auth.uid()
      and active
      and role in ('owner', 'admin')
  );
$$;

create or replace function public.is_business_operator()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.team_members
    where user_id = auth.uid()
      and active
      and role in ('owner', 'admin', 'operator')
  );
$$;

alter table public.team_members enable row level security;

drop policy if exists "Members read own membership" on public.team_members;
create policy "Members read own membership"
on public.team_members for select to authenticated
using (user_id = auth.uid() or public.is_business_admin());

drop policy if exists "Admins manage memberships" on public.team_members;
create policy "Admins manage memberships"
on public.team_members for all to authenticated
using (public.is_business_admin())
with check (public.is_business_admin());

alter table public.projects
  add column if not exists updated_by uuid references auth.users(id);

alter table public.quotations
  add column if not exists created_by uuid references auth.users(id),
  add column if not exists updated_by uuid references auth.users(id);

alter table public.customer_trackers
  add column if not exists created_by uuid references auth.users(id),
  add column if not exists updated_by uuid references auth.users(id);

alter table public.payments
  add column if not exists updated_by uuid references auth.users(id),
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists source_tracker_id uuid references public.customer_trackers(id) on delete restrict,
  add column if not exists source_paid_total numeric(12, 2);

alter table public.quotations
  add constraint quotations_revision_number_positive
  check (revision_number > 0) not valid;

alter table public.quotations
  add constraint quotations_total_amount_nonnegative
  check (total_amount >= 0) not valid;

alter table public.quotations
  add constraint quotations_supersedes_id_fkey
  foreign key (supersedes_id) references public.quotations(id) on delete restrict;

create unique index if not exists quotations_project_revision_unique
on public.quotations(project_id, revision_number)
where project_id is not null;

create unique index if not exists payments_tracker_total_unique
on public.payments(source_tracker_id, source_paid_total)
where source_tracker_id is not null and source_paid_total is not null;

create or replace function public.set_business_actor_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' and new.created_by is null then
    new.created_by = auth.uid();
  end if;
  new.updated_by = auth.uid();
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists projects_set_actor_fields on public.projects;
create trigger projects_set_actor_fields
before insert or update on public.projects
for each row execute function public.set_business_actor_fields();

drop trigger if exists quotations_set_actor_fields on public.quotations;
create trigger quotations_set_actor_fields
before insert or update on public.quotations
for each row execute function public.set_business_actor_fields();

drop trigger if exists customer_trackers_set_actor_fields on public.customer_trackers;
create trigger customer_trackers_set_actor_fields
before insert or update on public.customer_trackers
for each row execute function public.set_business_actor_fields();

drop trigger if exists payments_set_actor_fields on public.payments;
create trigger payments_set_actor_fields
before insert or update on public.payments
for each row execute function public.set_business_actor_fields();

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
  old_data := case
    when tg_op in ('UPDATE', 'DELETE')
    then to_jsonb(old) - array['images', 'payments', 'terms', 'model_file_url', 'model_file_path']::text[]
    else '{}'::jsonb
  end;
  new_data := case
    when tg_op in ('INSERT', 'UPDATE')
    then to_jsonb(new) - array['images', 'payments', 'terms', 'model_file_url', 'model_file_path']::text[]
    else '{}'::jsonb
  end;
  action_value := case
    when tg_table_name = 'payments' and tg_op = 'INSERT' then 'payment_recorded'
    when tg_op = 'INSERT' then 'created'
    when tg_op = 'UPDATE'
      and tg_table_name in ('projects', 'quotations', 'customer_trackers')
      and coalesce(old_data->>'status', old_data->>'stage', '') is distinct from coalesce(new_data->>'status', new_data->>'stage', '') then 'status_changed'
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

drop policy if exists "Authenticated admins manage quotations" on public.quotations;
drop policy if exists "Business members manage quotations" on public.quotations;
create policy "Business members read quotations"
on public.quotations for select to authenticated
using (public.is_business_member());
create policy "Operators create quotations"
on public.quotations for insert to authenticated
with check (public.is_business_operator());
create policy "Operators update quotations"
on public.quotations for update to authenticated
using (public.is_business_operator())
with check (public.is_business_operator());
create policy "Admins delete quotations"
on public.quotations for delete to authenticated
using (public.is_business_admin());

drop policy if exists "Authenticated admins manage customer trackers" on public.customer_trackers;
drop policy if exists "Business members manage customer trackers" on public.customer_trackers;
create policy "Business members read customer trackers"
on public.customer_trackers for select to authenticated
using (public.is_business_member());
create policy "Operators create customer trackers"
on public.customer_trackers for insert to authenticated
with check (public.is_business_operator());
create policy "Operators update customer trackers"
on public.customer_trackers for update to authenticated
using (public.is_business_operator())
with check (public.is_business_operator());
create policy "Admins delete customer trackers"
on public.customer_trackers for delete to authenticated
using (public.is_business_admin());

drop policy if exists "Authenticated admins manage projects" on public.projects;
drop policy if exists "Business members manage projects" on public.projects;
create policy "Business members read projects"
on public.projects for select to authenticated
using (public.is_business_member());
create policy "Operators create projects"
on public.projects for insert to authenticated
with check (public.is_business_operator());
create policy "Operators update projects"
on public.projects for update to authenticated
using (public.is_business_operator())
with check (public.is_business_operator());
create policy "Admins delete projects"
on public.projects for delete to authenticated
using (public.is_business_admin());

drop policy if exists "Authenticated admins manage payments" on public.payments;
drop policy if exists "Business members manage payments" on public.payments;
create policy "Business members read payments"
on public.payments for select to authenticated
using (public.is_business_member());
create policy "Operators record payments"
on public.payments for insert to authenticated
with check (public.is_business_operator());
create policy "Admins update payments"
on public.payments for update to authenticated
using (public.is_business_admin())
with check (public.is_business_admin());
create policy "Admins delete payments"
on public.payments for delete to authenticated
using (public.is_business_admin());

drop policy if exists "Authenticated admins read audit events" on public.audit_events;
create policy "Business members read audit events"
on public.audit_events for select to authenticated
using (public.is_business_member());

insert into storage.buckets (id, name, public)
values ('customer-model-files', 'customer-model-files', false)
on conflict (id) do update set public = false;

drop policy if exists "Authenticated users upload customer models" on storage.objects;
create policy "Business members upload customer models"
on storage.objects for insert to authenticated
with check (bucket_id = 'customer-model-files' and public.is_business_member());

drop policy if exists "Authenticated users read customer models" on storage.objects;
create policy "Business members read customer models"
on storage.objects for select to authenticated
using (bucket_id = 'customer-model-files' and public.is_business_member());

drop policy if exists "Authenticated users update customer models" on storage.objects;
create policy "Business members update customer models"
on storage.objects for update to authenticated
using (bucket_id = 'customer-model-files' and public.is_business_admin())
with check (bucket_id = 'customer-model-files' and public.is_business_admin());

drop policy if exists "Authenticated users delete customer models" on storage.objects;
create policy "Business members delete customer models"
on storage.objects for delete to authenticated
using (bucket_id = 'customer-model-files' and public.is_business_admin());
