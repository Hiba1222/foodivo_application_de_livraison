// Tiny i18n core: English text is the key, French comes from ./fr.
// Missing French entries fall back to English (run `node scripts/check-i18n.mjs`).
import { fr } from "./fr";

export type Locale = "en" | "fr";
export const LOCALES: Locale[] = ["en", "fr"];
export const DEFAULT_LOCALE: Locale = "en";
export const LOCALE_COOKIE = "lang";

export type Vars = Record<string, string | number>;
export type TFn = (key: string, vars?: Vars) => string;

export function isLocale(value: unknown): value is Locale {
  return value === "en" || value === "fr";
}

function interpolate(text: string, vars?: Vars) {
  if (!vars) return text;
  return text.replace(/\{(\w+)\}/g, (match, name) => (name in vars ? String(vars[name]) : match));
}

export function translate(locale: Locale, key: string, vars?: Vars) {
  const text = locale === "fr" ? fr[key] ?? key : key;
  return interpolate(text, vars);
}

export function makeT(locale: Locale): TFn {
  return (key, vars) => translate(locale, key, vars);
}

/** Identity translator (English) for code paths that don't care about language. */
export const englishT: TFn = (key, vars) => interpolate(key, vars);

/** Pick a locale from an Accept-Language header (first visit, no cookie yet). */
export function localeFromHeader(header: string | null | undefined): Locale {
  return header && /^\s*fr\b/i.test(header) ? "fr" : DEFAULT_LOCALE;
}

const DATE_TAG: Record<Locale, string> = { en: "en-GB", fr: "fr-FR" };

export function formatDateTime(locale: Locale, value: string | Date) {
  return new Date(value).toLocaleString(DATE_TAG[locale], { dateStyle: "medium", timeStyle: "short" });
}
export function formatDate(locale: Locale, value: string | Date) {
  return new Date(value).toLocaleDateString(DATE_TAG[locale], { dateStyle: "medium" });
}
export function formatTime(locale: Locale, value: string | Date) {
  return new Date(value).toLocaleTimeString(DATE_TAG[locale], { hour: "2-digit", minute: "2-digit" });
}

/** English labels for order statuses — pass through t() to translate. */
export const STATUS_TEXT: Record<string, string> = {
  pending: "Pending",
  accepted: "Accepted",
  rejected: "Rejected",
  ready_for_pickup: "Ready for pickup",
  driver_assigned: "Driver assigned",
  picked_up: "Picked up",
  delivered: "Delivered",
  cancelled: "Cancelled",
};

export function statusLabel(t: TFn, status: string) {
  return t(STATUS_TEXT[status] ?? status.replace(/_/g, " "));
}
