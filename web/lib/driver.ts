import { createClient } from "@/lib/supabase/server";
import type { DriverProfile } from "@/lib/types";

export async function getMyDriverProfile(): Promise<DriverProfile | null> {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const { data } = await supabase
    .from("driver_profiles")
    .select("*")
    .eq("id", user.id)
    .maybeSingle();

  return data;
}
