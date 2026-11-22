import { createClient } from "@/lib/supabase/server";
import type { Restaurant } from "@/lib/types";

// Each restaurant_owner has exactly one restaurant in this version of the app.
// Returns null if the owner hasn't completed onboarding yet.
export async function getMyRestaurant(): Promise<Restaurant | null> {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const { data } = await supabase
    .from("restaurants")
    .select("*")
    .eq("owner_id", user.id)
    .maybeSingle();

  return data;
}
