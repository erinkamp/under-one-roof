-- Every Bit of Home: licensing foundation, run only after reviewing existing accounts.
-- Run with public signup disabled. Existing confirmed accounts receive one complimentary entitlement.
begin;
create table if not exists public.portfolio_entitlements (
 user_id uuid primary key references auth.users(id) on delete cascade,
 source text not null check (source in ('founding','gift','purchase')),
 granted_at timestamptz not null default now()
);
alter table public.portfolio_entitlements enable row level security;
revoke all on public.portfolio_entitlements from anon, authenticated;
grant select on public.portfolio_entitlements to authenticated;
drop policy if exists read_own_entitlement on public.portfolio_entitlements;
create policy read_own_entitlement on public.portfolio_entitlements for select to authenticated using (user_id = auth.uid());
-- Explicit snapshot of confirmed accounts existing when this migration is applied.
insert into public.portfolio_entitlements(user_id,source)
select id,'founding' from auth.users where email_confirmed_at is not null
on conflict (user_id) do nothing;
create table if not exists public.portfolio_gift_codes (
 code_hash text primary key,
 created_at timestamptz not null default now(),
 expires_at timestamptz,
 redeemed_by uuid references auth.users(id),
 redeemed_at timestamptz
);
alter table public.portfolio_gift_codes enable row level security;
revoke all on public.portfolio_gift_codes from anon, authenticated;
-- No client write permissions. Future trusted backend issues cryptographically random codes.
-- This migration does NOT enforce entitlements on existing property tables or storage.
-- Do not reopen registration until those policies, redemption and payment verification are implemented and tested.
commit;
