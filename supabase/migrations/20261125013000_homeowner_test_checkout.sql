begin;

create table if not exists public.homeowner_test_checkout_receipts (
  checkout_session_id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  fulfilled_at timestamptz not null default now()
);

alter table public.homeowner_test_checkout_receipts enable row level security;
revoke all on public.homeowner_test_checkout_receipts from public, anon, authenticated;

create or replace function public.fulfill_homeowner_test_checkout(
  checkout_session_id text,
  account_id uuid
) returns void
language plpgsql
set search_path = ''
as $$
begin
  insert into public.homeowner_test_checkout_receipts (checkout_session_id, user_id)
  values (checkout_session_id, account_id)
  on conflict do nothing;

  if found then
    insert into public.portfolio_entitlements (user_id, source)
    values (account_id, 'purchase')
    on conflict (user_id) do nothing;
  end if;
end;
$$;

revoke all on function public.fulfill_homeowner_test_checkout(text, uuid)
  from public, anon, authenticated;
grant execute on function public.fulfill_homeowner_test_checkout(text, uuid)
  to service_role;

commit;
