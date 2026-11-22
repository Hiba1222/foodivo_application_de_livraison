"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

export async function setRestaurantApproval(restaurantId: string, approved: boolean) {
  const supabase = createClient();
  const { error } = await supabase
    .from("restaurants")
    .update({ is_approved: approved })
    .eq("id", restaurantId);

  if (error) throw new Error(error.message);
  revalidatePath("/admin/restaurants");
  revalidatePath("/admin");
}

export async function setDriverApproval(driverId: string, approved: boolean) {
  const supabase = createClient();
  const { error } = await supabase
    .from("driver_profiles")
    .update({ is_approved: approved })
    .eq("id", driverId);

  if (error) throw new Error(error.message);
  revalidatePath("/admin/drivers");
  revalidatePath("/admin");
}
