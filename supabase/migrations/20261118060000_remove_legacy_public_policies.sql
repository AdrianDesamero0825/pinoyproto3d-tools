drop policy if exists quotations_select_public on public.quotations;
drop policy if exists quotations_insert_public on public.quotations;

drop policy if exists customer_trackers_select_public on public.customer_trackers;
drop policy if exists customer_trackers_insert_authenticated on public.customer_trackers;
drop policy if exists customer_trackers_update_authenticated on public.customer_trackers;
drop policy if exists customer_trackers_delete_authenticated on public.customer_trackers;

notify pgrst, 'reload schema';
