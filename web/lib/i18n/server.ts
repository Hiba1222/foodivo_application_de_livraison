import { cookies, headers } from "next/headers";
import { LOCALE_COOKIE, isLocale, localeFromHeader, makeT, type Locale } from "./core";

/** Current language for Server Components / Server Actions. */
export function getLocale(): Locale {
  const fromCookie = cookies().get(LOCALE_COOKIE)?.value;
  if (isLocale(fromCookie)) return fromCookie;
  return localeFromHeader(headers().get("accept-language"));
}

export function getT() {
  return makeT(getLocale());
}
