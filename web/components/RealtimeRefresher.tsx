"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

/**
 * Drop this into any Server Component page. It subscribes to Postgres
 * changes on `table` (optionally narrowed with `filter`, e.g.
 * "restaurant_id=eq.<uuid>") and calls router.refresh() whenever a
 * matching row changes — which re-runs the page's server-side data
 * fetch and re-renders with fresh data, no manual reload needed.
 */
export default function RealtimeRefresher({
  table,
  filter,
}: {
  table: string;
  filter?: string;
}) {
  const router = useRouter();

  useEffect(() => {
    const supabase = createClient();
    const channel = supabase
      .channel(`realtime-${table}-${filter ?? "all"}`)
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table, filter },
        () => router.refresh()
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [table, filter]);

  return null;
}
