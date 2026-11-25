BEGIN;
CREATE TABLE public.portfolio_admins (
 user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE
);
ALTER TABLE public.portfolio_admins ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.portfolio_admins FROM PUBLIC, anon, authenticated;
CREATE TABLE public.portfolio_gift_codes (
 code_hash text PRIMARY KEY,
 created_at timestamptz NOT NULL DEFAULT now(),
 created_by uuid NOT NULL REFERENCES auth.users(id),
 expires_at timestamptz NOT NULL,
 redeemed_by uuid REFERENCES auth.users(id),
 redeemed_at timestamptz
);
ALTER TABLE public.portfolio_gift_codes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.portfolio_gift_codes FROM PUBLIC, anon, authenticated;
CREATE FUNCTION public.is_portfolio_admin() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$ SELECT EXISTS (SELECT 1 FROM public.portfolio_admins WHERE user_id = auth.uid()) $$;
REVOKE ALL ON FUNCTION public.is_portfolio_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_portfolio_admin() TO authenticated;
CREATE FUNCTION public.issue_portfolio_gift() RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE c text;
BEGIN
 IF NOT public.is_portfolio_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
 c := upper(replace(gen_random_uuid()::text,'-',''));
 INSERT INTO public.portfolio_gift_codes(code_hash,created_by,expires_at)
 VALUES (encode(sha256(convert_to(c,'UTF8')),'hex'),auth.uid(),now()+interval '1 year');
 RETURN c;
END $$;
REVOKE ALL ON FUNCTION public.issue_portfolio_gift() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.issue_portfolio_gift() TO authenticated;
CREATE FUNCTION public.redeem_portfolio_gift(gift_code text) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE u uuid := auth.uid(); h text;
BEGIN
 IF u IS NULL THEN RAISE EXCEPTION 'Sign in first'; END IF;
 IF EXISTS (SELECT 1 FROM public.portfolio_entitlements WHERE user_id=u) THEN RETURN false; END IF;
 UPDATE public.portfolio_gift_codes SET redeemed_by=u,redeemed_at=now()
 WHERE code_hash=encode(sha256(convert_to(upper(trim(gift_code)),'UTF8')),'hex')
 AND redeemed_at IS NULL AND expires_at>now() RETURNING code_hash INTO h;
 IF h IS NULL THEN RETURN false; END IF;
 INSERT INTO public.portfolio_entitlements(user_id,source) VALUES(u,'gift');
 RETURN true;
END $$;
REVOKE ALL ON FUNCTION public.redeem_portfolio_gift(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.redeem_portfolio_gift(text) TO authenticated;
-- Founder assignment must be performed separately in the SQL editor using verified user ID.
COMMIT;