"use client";

import { useEffect } from "react";
import { updateLocation } from "./actions";

// Mounted (invisibly) in the driver layout. While `enabled` is true it
// watches the browser's geolocation and reports updates to the server,
// which clients can then see on their order tracking map.
export default function LocationTracker({ enabled }: { enabled: boolean }) {
  useEffect(() => {
    if (!enabled) return;
    if (typeof window === "undefined" || !("geolocation" in navigator)) return;

    const watchId = navigator.geolocation.watchPosition(
      (position) => {
        updateLocation(position.coords.latitude, position.coords.longitude).catch(() => {
          // Non-fatal — next position update will retry.
        });
      },
      () => {
        // Permission denied or unavailable — silently skip; the driver
        // can still use the app, they just won't show on the client's map.
      },
      { enableHighAccuracy: true, maximumAge: 15000, timeout: 20000 }
    );

    return () => navigator.geolocation.clearWatch(watchId);
  }, [enabled]);

  return null;
}
