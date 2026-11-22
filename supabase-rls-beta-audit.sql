-- Under One Roof: REVIEW and run in Supabase SQL Editor before public beta.
-- This migration does not remove pre-existing policies. Review the final audit query:
-- any older permissive policies can still expose data, even when these policies exist.
alter table public.homeowner_properties enable row level security;
alter table public.homeowner_links enable row level security;
alter table public.homeowner_appliances enable row level security;

drop policy if exists uor_properties_owner_select on public.homeowner_properties;
drop policy if exists uor_properties_owner_insert on public.homeowner_properties;
drop policy if exists uor_properties_owner_update on public.homeowner_properties;
drop policy if exists uor_properties_owner_delete on public.homeowner_properties;
create policy uor_properties_owner_select on public.homeowner_properties for select to authenticated using (user_id=(select auth.uid()));
create policy uor_properties_owner_insert on public.homeowner_properties for insert to authenticated with check (user_id=(select auth.uid()));
create policy uor_properties_owner_update on public.homeowner_properties for update to authenticated using (user_id=(select auth.uid())) with check (user_id=(select auth.uid()));
create policy uor_properties_owner_delete on public.homeowner_properties for delete to authenticated using (user_id=(select auth.uid()));

drop policy if exists uor_links_owner_select on public.homeowner_links;
drop policy if exists uor_links_owner_insert on public.homeowner_links;
drop policy if exists uor_links_owner_update on public.homeowner_links;
drop policy if exists uor_links_owner_delete on public.homeowner_links;
create policy uor_links_owner_select on public.homeowner_links for select to authenticated using (user_id=(select auth.uid()));
create policy uor_links_owner_insert on public.homeowner_links for insert to authenticated with check (user_id=(select auth.uid()) and (property_id is null or exists(select 1 from public.homeowner_properties p where p.id=property_id and p.user_id=(select auth.uid()))));
create policy uor_links_owner_update on public.homeowner_links for update to authenticated using (user_id=(select auth.uid())) with check (user_id=(select auth.uid()) and (property_id is null or exists(select 1 from public.homeowner_properties p where p.id=property_id and p.user_id=(select auth.uid()))));
create policy uor_links_owner_delete on public.homeowner_links for delete to authenticated using (user_id=(select auth.uid()));

drop policy if exists uor_appliances_owner_select on public.homeowner_appliances;
drop policy if exists uor_appliances_owner_insert on public.homeowner_appliances;
drop policy if exists uor_appliances_owner_update on public.homeowner_appliances;
drop policy if exists uor_appliances_owner_delete on public.homeowner_appliances;
create policy uor_appliances_owner_select on public.homeowner_appliances for select to authenticated using (user_id=(select auth.uid()));
create policy uor_appliances_owner_insert on public.homeowner_appliances for insert to authenticated with check (user_id=(select auth.uid()) and (property_id is null or exists(select 1 from public.homeowner_properties p where p.id=property_id and p.user_id=(select auth.uid()))));
create policy uor_appliances_owner_update on public.homeowner_appliances for update to authenticated using (user_id=(select auth.uid())) with check (user_id=(select auth.uid()) and (property_id is null or exists(select 1 from public.homeowner_properties p where p.id=property_id and p.user_id=(select auth.uid()))));
create policy uor_appliances_owner_delete on public.homeowner_appliances for delete to authenticated using (user_id=(select auth.uid()));

-- Inspect all active policies, including any old policies that need manual removal.
select schemaname,tablename,policyname,permissive,roles,cmd,qual,with_check
from pg_policies
where schemaname='public' and tablename in ('homeowner_properties','homeowner_links','homeowner_appliances')
order by tablename,policyname;
