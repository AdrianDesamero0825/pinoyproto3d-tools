create or replace function public.create_quotation_workflow(
  p_record jsonb,
  p_quoted_amount numeric,
  p_supersedes_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  input_record record;
  saved_quotation public.quotations%rowtype;
  project_record public.projects%rowtype;
  tracker_record public.customer_trackers%rowtype;
  tracker_created boolean := false;
  next_revision integer;
begin
  if auth.uid() is null or not public.is_business_operator() then
    raise exception 'Only active business operators can create quotations';
  end if;

  select *
  into input_record
  from jsonb_to_record(p_record) as record_input(
    quotation_number text,
    project_name text,
    quotation_year integer,
    quotation_date date,
    customer_name text,
    contact text,
    address text,
    bill_to text,
    ship_to text,
    business_name text,
    business_contact text,
    business_email text,
    items jsonb,
    terms jsonb,
    payments jsonb,
    images jsonb,
    updated_at timestamptz
  );

  if nullif(trim(input_record.quotation_number), '') is null
     or nullif(trim(input_record.customer_name), '') is null
     or nullif(trim(input_record.project_name), '') is null then
    raise exception 'Quotation number, customer name, and project name are required';
  end if;

  insert into public.quotations (
    quotation_number,
    project_name,
    quotation_year,
    quotation_date,
    customer_name,
    contact,
    address,
    bill_to,
    ship_to,
    business_name,
    business_contact,
    business_email,
    items,
    terms,
    payments,
    images,
    total_amount,
    status,
    supersedes_id
  )
  values (
    input_record.quotation_number,
    input_record.project_name,
    input_record.quotation_year,
    input_record.quotation_date,
    input_record.customer_name,
    input_record.contact,
    input_record.address,
    input_record.bill_to,
    input_record.ship_to,
    input_record.business_name,
    input_record.business_contact,
    input_record.business_email,
    coalesce(input_record.items, '[]'::jsonb),
    coalesce(input_record.terms, '[]'::jsonb),
    coalesce(input_record.payments, '[]'::jsonb),
    coalesce(input_record.images, '[]'::jsonb),
    p_quoted_amount,
    'saved',
    p_supersedes_id
  )
  returning * into saved_quotation;

  insert into public.projects (customer_name, project_name)
  values (trim(input_record.customer_name), trim(input_record.project_name))
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
      trim(input_record.customer_name),
      trim(input_record.project_name),
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
    and id <> saved_quotation.id;

  update public.quotations
  set tracker_id = tracker_record.id,
      project_id = project_record.id,
      revision_number = next_revision,
      total_amount = p_quoted_amount,
      status = 'saved'
  where id = saved_quotation.id;

  return jsonb_build_object(
    'quotation_id', saved_quotation.id,
    'quotation_number', saved_quotation.quotation_number,
    'project_id', project_record.id,
    'tracker_id', tracker_record.id,
    'tracker_created', tracker_created,
    'stage', tracker_record.stage,
    'revision_number', next_revision
  );
end;
$$;

revoke all on function public.create_quotation_workflow(jsonb, numeric, uuid) from public;
grant execute on function public.create_quotation_workflow(jsonb, numeric, uuid) to authenticated;

revoke all on function public.sync_quotation_workflow(uuid, text, text, numeric, uuid) from authenticated;

notify pgrst, 'reload schema';
