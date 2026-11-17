create or replace function public.sync_quotation_workflow(
  p_quotation_id uuid,
  p_customer_name text,
  p_project_name text,
  p_quoted_amount numeric,
  p_supersedes_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  project_record public.projects%rowtype;
  tracker_record public.customer_trackers%rowtype;
  tracker_created boolean := false;
  next_revision integer;
begin
  if auth.uid() is null or not public.is_business_operator() then
    raise exception 'Only active business operators can synchronize quotations';
  end if;

  if not exists (
    select 1
    from public.quotations
    where id = p_quotation_id
  ) then
    raise exception 'Quotation does not exist';
  end if;

  insert into public.projects (customer_name, project_name)
  values (trim(p_customer_name), trim(p_project_name))
  on conflict (customer_key, project_key) do update
    set customer_name = excluded.customer_name,
        project_name = excluded.project_name
  returning * into project_record;

  select *
  into tracker_record
  from public.customer_trackers
  where customer_key = project_record.customer_key
    and project_key = project_record.project_key
  order by created_at desc
  limit 1
  for update;

  if tracker_record.id is null then
    insert into public.customer_trackers (
      customer_name,
      project_name,
      project_id,
      stage,
      quoted_amount,
      paid_amount,
      updated_at
    )
    values (
      trim(p_customer_name),
      trim(p_project_name),
      project_record.id,
      'Quotation Sent',
      p_quoted_amount,
      0,
      now()
    )
    returning * into tracker_record;
    tracker_created := true;
  else
    update public.customer_trackers
    set project_id = project_record.id,
        quoted_amount = case
          when tracker_record.stage in ('Inquiry', 'Quotation Sent') then p_quoted_amount
          else quoted_amount
        end,
        stage = case
          when tracker_record.stage in ('Inquiry', 'Quotation Sent') then 'Quotation Sent'
          else stage
        end,
        updated_at = now()
    where id = tracker_record.id
    returning * into tracker_record;
  end if;

  select coalesce(max(revision_number), 0) + 1
  into next_revision
  from public.quotations
  where project_id = project_record.id
    and id <> p_quotation_id;

  update public.quotations
  set tracker_id = tracker_record.id,
      project_id = project_record.id,
      revision_number = next_revision,
      total_amount = p_quoted_amount,
      status = 'saved',
      supersedes_id = p_supersedes_id
  where id = p_quotation_id;

  return jsonb_build_object(
    'project_id', project_record.id,
    'tracker_id', tracker_record.id,
    'tracker_created', tracker_created,
    'stage', tracker_record.stage,
    'revision_number', next_revision
  );
end;
$$;

revoke all on function public.sync_quotation_workflow(uuid, text, text, numeric, uuid) from public;
grant execute on function public.sync_quotation_workflow(uuid, text, text, numeric, uuid) to authenticated;
