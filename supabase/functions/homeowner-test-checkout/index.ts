import Stripe from "npm:stripe@18.5.0";
import { createClient } from "npm:@supabase/supabase-js@2.78.0";

const key = Deno.env.get("STRIPE_TEST_SECRET_KEY") ?? "";
const webhookSecret = Deno.env.get("STRIPE_TEST_WEBHOOK_SECRET") ?? "";
const testUserId = Deno.env.get("CHECKOUT_TEST_USER_ID") ?? "";
const appOrigin = "https://everybitofhome.com";
const amount = 699;
const cors = {
  "Access-Control-Allow-Origin": appOrigin,
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Cache-Control": "no-store",
};

function reply(body: object, status = 200) {
  return Response.json(body, { status, headers: cors });
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response(null, { headers: cors });
  if (request.method !== "POST") return reply({ error: "Method not allowed" }, 405);
  if (!key.startsWith("sk_test_") || !testUserId || !webhookSecret) {
    return reply({ error: "Test checkout is unavailable" }, 503);
  }

  const stripe = new Stripe(key, { httpClient: Stripe.createFetchHttpClient() });
  const db = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );

  try {
    if (new URL(request.url).pathname.endsWith("/webhook")) {
      const signature = request.headers.get("stripe-signature");
      if (!signature) return reply({ error: "Missing signature" }, 400);
      let event: Stripe.Event;
      try {
        event = await stripe.webhooks.constructEventAsync(
          await request.text(), signature, webhookSecret, undefined,
          Stripe.createSubtleCryptoProvider(),
        );
      } catch {
        return reply({ error: "Invalid signature" }, 400);
      }

      if (event.livemode || event.type !== "checkout.session.completed") {
        return reply({ received: true });
      }

      const session = event.data.object;
      if (session.livemode || session.mode !== "payment" ||
        session.payment_status !== "paid" || session.amount_total !== amount ||
        session.currency !== "usd" || session.client_reference_id !== testUserId ||
        session.metadata?.purpose !== "homeowner-test-checkout") {
        return reply({ received: true });
      }

      const { error } = await db.rpc("fulfill_homeowner_test_checkout", {
        checkout_session_id: session.id,
        account_id: testUserId,
      });
      if (error) throw error;
      return reply({ received: true });
    }

    const token = request.headers.get("authorization")?.match(/^Bearer (\S+)$/i)?.[1];
    if (!token) return reply({ error: "Sign in to continue" }, 401);
    const { data: { user }, error: authError } = await db.auth.getUser(token);
    if (authError || !user) return reply({ error: "Sign in to continue" }, 401);
    if (user.id !== testUserId || !user.email_confirmed_at) {
      return reply({ error: "Test checkout is restricted" }, 403);
    }

    const { data: entitlement, error } = await db.from("portfolio_entitlements")
      .select("user_id").eq("user_id", user.id).maybeSingle();
    if (error) throw error;
    if (entitlement) return reply({ error: "This account already has access" }, 409);

    const session = await stripe.checkout.sessions.create({
      mode: "payment",
      payment_method_types: ["card"],
      client_reference_id: user.id,
      customer_email: user.email,
      metadata: { purpose: "homeowner-test-checkout" },
      line_items: [{
        price_data: {
          currency: "usd",
          unit_amount: amount,
          product_data: { name: "Every Bit of Home homeowner portfolio (test)" },
        },
        quantity: 1,
      }],
      success_url: appOrigin + "/#home",
      cancel_url: appOrigin + "/#home",
    });

    return reply({ url: session.url });
  } catch {
    return reply({ error: "Test checkout could not be processed" }, 500);
  }
});
