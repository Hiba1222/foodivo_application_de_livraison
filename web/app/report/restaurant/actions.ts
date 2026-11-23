"use server";

import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { sendRestaurantReportEmail } from "@/lib/email";

const PLATFORM_FEE_RATE = 0.1;

export async function emailRestaurantReport(restaurantId: string, period: string) {
  const supabase = createClient();
  const admin = createAdminClient();

  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return;

  const days = period === "all" ? null : Number(period) || 30;
  const since = days
    ? (() => { const d = new Date(); d.setDate(d.getDate() - days); return d.toISOString(); })()
    : null;

  let query = supabase
    .from("orders")
    .select("id, subtotal_cents, delivered_at, profiles!orders_client_id_fkey(full_name)")
    .eq("restaurant_id", restaurantId)
    .eq("status", "delivered")
    .order("delivered_at", { ascending: false });

  if (since) query = query.gte("created_at", since);
  const { data: orders } = await query;

  const { data: restaurant } = await supabase
    .from("restaurants")
    .select("name")
    .eq("id", restaurantId)
    .single();

  const { data: authUser } = await admin.auth.admin.getUserById(user.id);
  const email = authUser.user?.email;
  if (!email || !orders) return;

  const enriched = orders.map((o) => ({
    ...o,
    fee: Math.round(o.subtotal_cents * PLATFORM_FEE_RATE),
    net: Math.round(o.subtotal_cents * (1 - PLATFORM_FEE_RATE)),
  }));

  await sendRestaurantReportEmail(email, {
    restaurantName: restaurant?.name ?? "",
    period,
    orders: enriched,
  });
}
