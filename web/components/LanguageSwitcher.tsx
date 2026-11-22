"use client";

import { useEffect, useRef, useState } from "react";
import { useI18n } from "@/lib/i18n/client";
import type { Locale } from "@/lib/i18n/core";

const OPTIONS: { value: Locale; code: string; flag: string; name: string }[] = [
  { value: "en", code: "EN", flag: "🇬🇧", name: "English" },
  { value: "fr", code: "FR", flag: "🇫🇷", name: "Français" },
];

/**
 * Language picker: a pill (flag + code + chevron) that opens a small animated menu.
 * `compact` hides the code on very small screens; `glass` suits coloured/blurred backgrounds.
 */
export default function LanguageSwitcher({
  compact = false,
  glass = false,
  className = "",
}: {
  compact?: boolean;
  glass?: boolean;
  className?: string;
}) {
  const { locale, setLocale, t } = useI18n();
  const [open, setOpen] = useState(false);
  const rootRef = useRef<HTMLDivElement>(null);
  const current = OPTIONS.find((o) => o.value === locale) ?? OPTIONS[0];

  // Close on outside click / Escape.
  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => {
      if (!rootRef.current?.contains(e.target as Node)) setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setOpen(false);
    document.addEventListener("mousedown", onDown);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onDown);
      document.removeEventListener("keydown", onKey);
    };
  }, [open]);

  function choose(value: Locale) {
    setOpen(false);
    if (value !== locale) setLocale(value);
  }

  return (
    <div ref={rootRef} className={`relative ${className}`}>
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        aria-haspopup="menu"
        aria-expanded={open}
        aria-label={`${t("Language")}: ${current.name}`}
        className={`group flex items-center gap-2 rounded-full py-1.5 pl-2 pr-2.5 text-sm font-semibold shadow-sm ring-1 transition duration-200 hover:-translate-y-0.5 hover:shadow-md ${
          glass
            ? "bg-white/70 text-slate-800 ring-white/80 backdrop-blur-md hover:bg-white/90"
            : "bg-white text-slate-700 ring-slate-200 hover:ring-brand-300"
        } ${open ? "ring-2 ring-brand-400" : ""}`}
      >
        {/* Globe */}
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth={1.7}
          className="h-4 w-4 text-slate-400 transition group-hover:rotate-12 group-hover:text-brand-600"
          aria-hidden="true"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            d="M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18Zm0 0c2.5-2.5 3.75-5.5 3.75-9S14.5 5.5 12 3m0 18c-2.5-2.5-3.75-5.5-3.75-9S9.5 5.5 12 3M3.5 9h17m-17 6h17"
          />
        </svg>
        <span key={current.value} className="animate-pop text-base leading-none">
          {current.flag}
        </span>
        <span className={compact ? "hidden min-[380px]:inline" : ""}>{current.code}</span>
        <svg
          viewBox="0 0 20 20"
          fill="currentColor"
          className={`h-4 w-4 text-slate-400 transition-transform duration-200 ${open ? "rotate-180" : ""}`}
          aria-hidden="true"
        >
          <path
            fillRule="evenodd"
            d="M5.23 7.21a.75.75 0 0 1 1.06.02L10 11.17l3.71-3.94a.75.75 0 1 1 1.08 1.04l-4.25 4.5a.75.75 0 0 1-1.08 0l-4.25-4.5a.75.75 0 0 1 .02-1.06Z"
            clipRule="evenodd"
          />
        </svg>
      </button>

      {open && (
        <div
          role="menu"
          className="absolute right-0 top-full z-50 mt-2 w-48 origin-top-right animate-scale-in overflow-hidden rounded-2xl bg-white p-1.5 shadow-lift ring-1 ring-slate-200"
        >
          <p className="px-3 pb-1 pt-1.5 text-[11px] font-semibold uppercase tracking-wider text-slate-400">
            {t("Language")}
          </p>
          {OPTIONS.map((o) => {
            const active = o.value === locale;
            return (
              <button
                key={o.value}
                type="button"
                role="menuitemradio"
                aria-checked={active}
                onClick={() => choose(o.value)}
                className={`flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-left text-sm transition ${
                  active ? "bg-brand-50 font-semibold text-brand-700" : "text-slate-700 hover:bg-slate-50"
                }`}
              >
                <span className="text-lg leading-none">{o.flag}</span>
                <span className="flex-1">{o.name}</span>
                <span className="text-xs font-bold text-slate-400">{o.code}</span>
                {active && (
                  <svg viewBox="0 0 20 20" fill="currentColor" className="h-4 w-4 animate-pop text-brand-600" aria-hidden="true">
                    <path
                      fillRule="evenodd"
                      d="M16.7 5.3a1 1 0 0 1 0 1.4l-7.5 7.5a1 1 0 0 1-1.4 0l-3.5-3.5a1 1 0 1 1 1.4-1.4l2.8 2.79 6.8-6.8a1 1 0 0 1 1.4 0Z"
                      clipRule="evenodd"
                    />
                  </svg>
                )}
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
}
