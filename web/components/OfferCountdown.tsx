"use client";

import { useEffect, useState } from "react";
import { useI18n } from "@/lib/i18n/client";

/** "Ends in 2d 4h" / "Ends in 3h 12m" — ticks every 30s. Renders nothing until mounted (no hydration mismatch). */
export default function OfferCountdown({ endsAt, className = "" }: { endsAt: string; className?: string }) {
  const { t } = useI18n();
  const [now, setNow] = useState<number | null>(null);

  useEffect(() => {
    setNow(Date.now());
    const id = setInterval(() => setNow(Date.now()), 30_000);
    return () => clearInterval(id);
  }, []);

  if (now === null) return null;
  const ms = new Date(endsAt).getTime() - now;
  if (ms <= 0) return null;

  const mins = Math.floor(ms / 60_000);
  const days = Math.floor(mins / 1440);
  const hours = Math.floor((mins % 1440) / 60);
  const rest = mins % 60;
  const left = days > 0 ? `${days}${t("d")} ${hours}${t("h")}` : hours > 0 ? `${hours}${t("h")} ${rest}m` : `${rest}m`;
  const urgent = ms < 24 * 3600_000;

  return (
    <span
      className={`inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[11px] font-bold ${
        urgent ? "animate-pulse bg-red-100 text-red-700" : "bg-slate-900/80 text-white"
      } ${className}`}
    >
      ⏳ {t("Ends in {time}", { time: left })}
    </span>
  );
}
