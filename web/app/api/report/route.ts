import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { sendDriverReportEmail, sendRestaurantReportEmail } from "@/lib/email";

const PLATFORM_FEE_RATE = 0.1;

export async function POST(req: Request) {
  const authHeader = req.headers.get("authorization") ?? "";
  const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : null;
  if (!token) return Response.json({ error: "Unauthorized" }, { status: 401 });

  let body: { type?: string; period?: string };
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: "Bad request" }, { status: 400 });
  }

  const supabase = createClient();
  const { data: { user }, error: authError } = await supabase.auth.getUser(token);
  if (authError || !user) return Response.json({ error: "Unauthorized" }, { status: 401 });

  const admin = createAdminClient();
  const { data: authUser } = await admin.auth.admin.getUserById(user.id);
  const email = authUser.user?.email;
  if (!email) return Response.json({ error: "No email" }, { status: 400 });

  const period = body.period ?? "30";
  const days = period === "all" ? null : Number(period) || 30;
  const since = days
    ? (() => { const d = new Date(); d.setDate(d.getDate() - days); return d.toISOString(); })()
    : null;

  if (body.type === "driver") {
    let query = supabase
      .from("orders")
      .select("id, delivery_fee_cents, delivered_at, restaurants(name)")
      .eq("driver_id", user.id)
      .eq("status", "delivered")
      .order("delivered_at", { ascending: false });
    if (since) query = query.gte("created_at", since);
    const { data: orders } = await query;

    const { data: profile } = await supabase.from("profiles").select("full_name").eq("id", user.id).single();
    const enriched = (orders ?? []).map((o) => {
      const restaurants = Array.isArray(o.restaurants) ? (o.restaurants[0] ?? null) : o.restaurants;
      return {
        ...o,
        restaurants,
        cut: Math.round(o.delivery_fee_cents * PLATFORM_FEE_RATE),
        net: Math.round(o.delivery_fee_cents * (1 - PLATFORM_FEE_RATE)),
      };
    });

    await sendDriverReportEmail(email, {
      driverName: (profile as any)?.full_name ?? "",
      period,
      orders: enriched,
    });
    return Response.json({ ok: true });
  }

  if (body.type === "restaurant") {
    const { data: restaurant } = await supabase
      .from("restaurants")
      .select("id, name")
      .eq("owner_id", user.id)
      .maybeSingle();
    if (!restaurant) return Response.json({ error: "Not a restaurant owner" }, { status: 403 });

    let query = supabase
      .from("orders")
      .select("id, subtotal_cents, delivered_at, profiles!orders_client_id_fkey(full_name)")
      .eq("restaurant_id", restaurant.id)
      .eq("status", "delivered")
      .order("delivered_at", { ascending: false });
    if (since) query = query.gte("created_at", since);
    const { data: orders } = await query;

    const enriched = (orders ?? []).map((o) => ({
      ...o,
      fee: Math.round(o.subtotal_cents * PLATFORM_FEE_RATE),
      net: Math.round(o.subtotal_cents * (1 - PLATFORM_FEE_RATE)),
    }));

    await sendRestaurantReportEmail(email, {
      restaurantName: restaurant.name,
      period,
      orders: enriched,
    });
    return Response.json({ ok: true });
  }

  return Response.json({ error: "type must be 'driver' or 'restaurant'" }, { status: 400 });
}
