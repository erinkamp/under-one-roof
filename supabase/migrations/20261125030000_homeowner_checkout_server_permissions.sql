begin;

grant select (user_id) on public.portfolio_entitlements to service_role;

alter function public.fulfill_homeowner_test_checkout(text, uuid)
  security definer;

commit;
