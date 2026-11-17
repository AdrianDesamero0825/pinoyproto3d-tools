drop policy if exists "Operators update quotations" on public.quotations;
create policy "Admins update quotations"
on public.quotations for update to authenticated
using (public.is_business_admin())
with check (public.is_business_admin());

drop policy if exists "Operators update customer trackers" on public.customer_trackers;
create policy "Admins update customer trackers"
on public.customer_trackers for update to authenticated
using (public.is_business_admin())
with check (public.is_business_admin());

drop policy if exists "Operators update projects" on public.projects;
create policy "Admins update projects"
on public.projects for update to authenticated
using (public.is_business_admin())
with check (public.is_business_admin());
