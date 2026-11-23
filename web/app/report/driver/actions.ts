"use server";

import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { sendDriverReportEmail } from "@/lib/email";

const PLATFORM_FEE_RATE = 0.1;

export async function emailDriverReport(period: string) {
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
    .select("id, delivery_fee_cents, delivered_at, restaurants(name)")
    .eq("driver_id", user.id)
    .eq("status", "delivered")
    .order("delivered_at", { ascending: false });

  if (since) query = query.gte("created_at", since);
  const { data: orders } = await query;

  const { data: profile } = await supabase
    .from("profiles")
    .select("full_name")
    .eq("id", user.id)
    .single();

  const { data: authUser } = await admin.auth.admin.getUserById(user.id);
  const email = authUser.user?.email;
  if (!email || !orders) return;

  const enriched = orders.map((o) => ({
    ...o,
    cut: Math.round(o.delivery_fee_cents * PLATFORM_FEE_RATE),
    net: Math.round(o.delivery_fee_cents * (1 - PLATFORM_FEE_RATE)),
  }));

  await sendDriverReportEmail(email, {
    driverName: (profile as any)?.full_name ?? "",
    period,
    orders: enriched,
  });
}
