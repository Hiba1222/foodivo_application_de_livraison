import { getT } from "@/lib/i18n/server";

export default function DriverLocationMap({
  latitude,
  longitude,
}: {
  latitude: number;
  longitude: number;
}) {
  // Small bounding box around the driver's point — no API key required.
  const delta = 0.01;
  const bbox = [longitude - delta, latitude - delta, longitude + delta, latitude + delta].join(
    "%2C"
  );
  const src = `https://www.openstreetmap.org/export/embed.html?bbox=${bbox}&marker=${latitude}%2C${longitude}`;

  return (
    <iframe
      title={getT()("Driver location")}
      className="mt-3 h-56 w-full rounded-xl border border-slate-200"
      src={src}
      loading="lazy"
    />
  );
}
