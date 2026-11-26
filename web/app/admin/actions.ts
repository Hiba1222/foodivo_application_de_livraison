"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { sendApprovalEmail } from "@/lib/email";

type ApprovalAction = "approved" | "disapproved" | "suspended";

async function getEmailForUser(userId: string): Promise<string | null> {
  try {
    const admin = createAdminClient();
    const { data } = await admin.auth.admin.getUserById(userId);
    return data.user?.email ?? null;
  } catch {
    return null;
  }
}

export async function setRestaurantApproval(restaurantId: string, approved: boolean) {
  const supabase = createClient();

  const { data: restaurant, error: fetchError } = await supabase
    .from("restaurants")
    .select("owner_id, name, is_approved")
    .eq("id", restaurantId)
    .single();

  if (fetchError) throw new Error(fetchError.message);

  const { error } = await supabase
    .from("restaurants")
    .update({ is_approved: approved })
    .eq("id", restaurantId);

  if (error) throw new Error(error.message);

  const action: ApprovalAction = approved ? "approved" : "suspended";
  const email = await getEmailForUser(restaurant.owner_id);
  if (email) await sendApprovalEmail(email, "restaurant", action, restaurant.name);

  revalidatePath("/admin/restaurants");
  revalidatePath("/admin");
}

export async function disapproveRestaurant(restaurantId: string) {
  const supabase = createClient();

  const { data: restaurant, error: fetchError } = await supabase
    .from("restaurants")
    .select("owner_id, name")
    .eq("id", restaurantId)
    .single();

  if (fetchError) throw new Error(fetchError.message);

  const { data: deleted, error } = await supabase
    .from("restaurants")
    .delete()
    .eq("id", restaurantId)
    .select("id");

  if (error) throw new Error(error.message);
  if (!deleted?.length) throw new Error("Restaurant could not be deleted");

  const email = await getEmailForUser(restaurant.owner_id);
  if (email) await sendApprovalEmail(email, "restaurant", "disapproved", restaurant.name);

  revalidatePath("/admin/restaurants");
  revalidatePath("/admin");
}

export async function setDriverApproval(driverId: string, approved: boolean) {
  const supabase = createClient();

  const { data: driver, error: fetchError } = await supabase
    .from("driver_profiles")
    .select("id, profiles(full_name)")
    .eq("id", driverId)
    .single();

  if (fetchError) throw new Error(fetchError.message);

  const { error } = await supabase
    .from("driver_profiles")
    .update({ is_approved: approved })
    .eq("id", driverId);

  if (error) throw new Error(error.message);

  const action: ApprovalAction = approved ? "approved" : "suspended";
  const name = (driver as any).profiles?.full_name ?? null;
  const email = await getEmailForUser(driverId);
  if (email) await sendApprovalEmail(email, "driver", action, name);

  revalidatePath("/admin/drivers");
  revalidatePath("/admin");
}

export async function disapproveDriver(driverId: string) {
  const supabase = createClient();

  const { data: driver, error: fetchError } = await supabase
    .from("driver_profiles")
    .select("id, profiles(full_name)")
    .eq("id", driverId)
    .single();

  if (fetchError) throw new Error(fetchError.message);

  // Send email before deleting
  const name = (driver as any).profiles?.full_name ?? null;
  const email = await getEmailForUser(driverId);
  if (email) await sendApprovalEmail(email, "driver", "disapproved", name);

  const { error } = await supabase
    .from("driver_profiles")
    .delete()
    .eq("id", driverId);

  if (error) throw new Error(error.message);

  revalidatePath("/admin/drivers");
  revalidatePath("/admin");
}
