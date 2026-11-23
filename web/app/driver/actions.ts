"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { getT } from "@/lib/i18n/server";
import { sendOrderStatusEmails } from "@/lib/email";
import { sendPushToClient } from "@/lib/fcm";

async function requireUser() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");
  return { supabase, user };
}

// ---------- Onboarding / settings ----------

export async function createDriverProfile(formData: FormData) {
  const { supabase, user } = await requireUser();

  const { error } = await supabase.from("driver_profiles").insert({
    id: user.id,
    vehicle_type: formData.get("vehicle_type") as string,
    license_plate: (formData.get("license_plate") as string) || null,
  });
  if (error) throw new Error(error.message);

  const phone = formData.get("phone") as string;
  if (phone) {
    await supabase.from("profiles").update({ phone }).eq("id", user.id);
  }

  revalidatePath("/driver");
}

export async function updateDriverProfile(formData: FormData) {
  const { supabase, user } = await requireUser();

  const { error: driverError } = await supabase
    .from("driver_profiles")
    .update({
      vehicle_type: formData.get("vehicle_type") as string,
      license_plate: (formData.get("license_plate") as string) || null,
    })
    .eq("id", user.id);
  if (driverError) throw new Error(driverError.message);

  const profileUpdate: Record<string, string> = { phone: formData.get("phone") as string };
  const fullName = (formData.get("full_name") as string)?.trim();
  if (fullName) profileUpdate.full_name = fullName;

  const { error: profileError } = await supabase
    .from("profiles")
    .update(profileUpdate)
    .eq("id", user.id);
  if (profileError) throw new Error(profileError.message);

  revalidatePath("/driver/settings");
  redirect("/driver/settings?saved=1");
}

export async function toggleOnline(isOnline: boolean) {
  const { supabase, user } = await requireUser();
  const { error } = await supabase
    .from("driver_profiles")
    .update({ is_online: isOnline })
    .eq("id", user.id);
  if (error) throw new Error(error.message);
  revalidatePath("/driver");
  revalidatePath("/driver/available");
}

export async function updateLocation(latitude: number, longitude: number) {
  const { supabase, user } = await requireUser();
  await supabase
    .from("driver_profiles")
    .update({
      current_latitude: latitude,
      current_longitude: longitude,
      last_location_update: new Date().toISOString(),
    })
    .eq("id", user.id);
  await supabase.from("driver_locations_history").insert({
    driver_id: user.id,
    latitude,
    longitude,
  });
}

// ─── Email helper ─────────────────────────────────────────────────────────────

async function notifyOrderStatus(supabase: ReturnType<typeof createClient>, orderId: string, status: string, driverName: string | null) {
  void (async () => {
    try {
      const { data: order } = await supabase
        .from("orders")
        .select("client_id, total_cents, restaurants(name, owner_id), profiles!orders_client_id_fkey(full_name)")
        .eq("id", orderId)
        .single();
      if (!order) return;
      const restaurant = order.restaurants as any;
      const admin = createAdminClient();
      const [clientRes, restaurantRes] = await Promise.all([
        admin.auth.admin.getUserById(order.client_id),
        restaurant?.owner_id ? admin.auth.admin.getUserById(restaurant.owner_id) : Promise.resolve({ data: { user: null } }),
      ]);
      await sendOrderStatusEmails({
        orderId,
        status,
        clientEmail: clientRes.data.user?.email ?? null,
        clientName: (order.profiles as any)?.full_name ?? null,
        restaurantEmail: restaurantRes.data.user?.email ?? null,
        restaurantName: restaurant?.name ?? null,
        driverName,
        totalCents: order.total_cents,
      });
      sendPushToClient(order.client_id, status);
    } catch {}
  })();
}

// ---------- Deliveries ----------

export async function acceptDelivery(orderId: string) {
  const { supabase, user } = await requireUser();

  // Guard against two drivers accepting the same order at once: only
  // succeeds if the order is still unassigned and ready for pickup.
  const { data, error } = await supabase
    .from("orders")
    .update({ driver_id: user.id, status: "driver_assigned" })
    .eq("id", orderId)
    .eq("status", "ready_for_pickup")
    .is("driver_id", null)
    .select("id")
    .single();

  if (error || !data) {
    throw new Error(getT()("This delivery was just taken by another driver."));
  }

  await supabase.from("order_status_history").insert({
    order_id: orderId,
    status: "driver_assigned",
    changed_by: user.id,
  });

  const { data: profile } = await supabase.from("profiles").select("full_name").eq("id", user.id).single();
  notifyOrderStatus(supabase, orderId, "driver_assigned", (profile as any)?.full_name ?? null);

  revalidatePath("/driver/available");
  revalidatePath("/driver/my-deliveries");
}

export async function markPickedUp(orderId: string) {
  const { supabase, user } = await requireUser();
  const { error } = await supabase
    .from("orders")
    .update({ status: "picked_up", picked_up_at: new Date().toISOString() })
    .eq("id", orderId)
    .eq("driver_id", user.id);
  if (error) throw new Error(error.message);

  await supabase.from("order_status_history").insert({
    order_id: orderId,
    status: "picked_up",
    changed_by: user.id,
  });
  notifyOrderStatus(supabase, orderId, "picked_up", null);
  revalidatePath("/driver/my-deliveries");
}

export async function markDelivered(orderId: string) {
  const { supabase, user } = await requireUser();
  const { error } = await supabase
    .from("orders")
    .update({
      status: "delivered",
      delivered_at: new Date().toISOString(),
      payment_status: "paid",
    })
    .eq("id", orderId)
    .eq("driver_id", user.id);
  if (error) throw new Error(error.message);

  await supabase.from("order_status_history").insert({
    order_id: orderId,
    status: "delivered",
    changed_by: user.id,
  });
  notifyOrderStatus(supabase, orderId, "delivered", null);
  revalidatePath("/driver/my-deliveries");
  revalidatePath("/driver/history");
}
