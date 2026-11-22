"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getT } from "@/lib/i18n/server";

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

  const { error: profileError } = await supabase
    .from("profiles")
    .update({ phone: formData.get("phone") as string })
    .eq("id", user.id);
  if (profileError) throw new Error(profileError.message);

  revalidatePath("/driver/settings");
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
  revalidatePath("/driver/my-deliveries");
  revalidatePath("/driver/history");
}
