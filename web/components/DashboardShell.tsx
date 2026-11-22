"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { useOptionalCart } from "@/lib/cart-context";
import NavIcon from "./NavIcon";
import LanguageSwitcher from "./LanguageSwitcher";
import Logo from "./Logo";
import { useI18n } from "@/lib/i18n/client";

interface NavItem {
  href: string;
  label: string;
}

/** Most specific nav item that matches the current path (so /client/orders/123 highlights "My orders"). */
function activeHref(pathname: string, items: NavItem[]) {
  return items
    .filter((i) => pathname === i.href || pathname.startsWith(i.href + "/"))
    .sort((a, b) => b.href.length - a.href.length)[0]?.href;
}

function CartBadge() {
  const cart = useOptionalCart();
  const [bump, setBump] = useState(false);
  const tick = cart?.addTick ?? 0;

  useEffect(() => {
    if (!tick) return;
    setBump(true);
    const timer = setTimeout(() => setBump(false), 500);
    return () => clearTimeout(timer);
  }, [tick]);

  if (!cart || cart.itemCount === 0) return null;
  return (
    <span
      className={`ml-auto flex h-5 min-w-5 items-center justify-center rounded-full bg-brand-600 px-1.5 text-[11px] font-bold text-white shadow-glow ${
        bump ? "animate-pop" : ""
      }`}
    >
      {cart.itemCount}
    </span>
  );
}

export default function DashboardShell({
  roleLabel,
  navItems,
  children,
}: {
  roleLabel: string;
  navItems: NavItem[];
  children: React.ReactNode;
}) {
  const pathname = usePathname();
  const router = useRouter();
  const supabase = createClient();
  const current = activeHref(pathname, navItems);
  const { t } = useI18n();

  async function handleLogout() {
    await supabase.auth.signOut();
    router.replace("/login");
  }

  const isCart = (href: string) => href.endsWith("/cart");

  return (
    <div className="flex min-h-screen bg-slate-50">
      {/* Desktop sidebar */}
      <aside className="sticky top-0 hidden h-screen w-64 shrink-0 flex-col border-r border-slate-200/80 bg-white/80 backdrop-blur md:flex">
        <Link href={navItems[0]?.href ?? "/"} className="group block px-5 pb-4 pt-5">
          <Logo className="h-14 transition duration-300 group-hover:-rotate-2 group-hover:scale-105" />
          <span className="ml-1 mt-1 inline-block rounded-full bg-brand-50 px-2.5 py-0.5 text-[10px] font-bold uppercase tracking-widest text-brand-700">
            {t(roleLabel)}
          </span>
        </Link>

        <nav className="flex-1 space-y-1 px-3">
          {navItems.map((item, i) => {
            const active = item.href === current;
            return (
              <Link
                key={item.href}
                href={item.href}
                style={{ animationDelay: `${i * 50}ms` }}
                className={`group relative flex animate-fade-up items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition ${
                  active
                    ? "bg-gradient-to-r from-brand-50 to-transparent text-brand-700"
                    : "text-slate-600 hover:bg-slate-100 hover:text-slate-900"
                }`}
              >
                <span
                  className={`absolute left-0 top-1/2 h-6 w-1 -translate-y-1/2 rounded-r-full bg-brand-600 transition-all duration-300 ${
                    active ? "opacity-100" : "h-0 opacity-0"
                  }`}
                />
                <NavIcon
                  label={item.label}
                  className={`h-5 w-5 transition duration-300 group-hover:scale-110 ${
                    active ? "text-brand-600" : "text-slate-400 group-hover:text-slate-600"
                  }`}
                />
                <span>{t(item.label)}</span>
                {isCart(item.href) && <CartBadge />}
              </Link>
            );
          })}
        </nav>

        <div className="border-t border-slate-100 p-3">
          <button
            onClick={handleLogout}
            className="group flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-left text-sm font-medium text-slate-500 hover:bg-red-50 hover:text-red-600"
          >
            <NavIcon label="Sign out" className="h-5 w-5 transition group-hover:translate-x-0.5" />
            {t("Sign out")}
          </button>
        </div>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        {/* Mobile top bar */}
        <header className="sticky top-0 z-30 flex items-center justify-between border-b border-slate-200/80 bg-white/80 px-4 py-3 backdrop-blur md:hidden">
          <span className="flex items-center gap-2">
            <Logo className="h-9" />
            <span className="rounded-full bg-brand-50 px-2 py-0.5 text-[9px] font-bold uppercase tracking-widest text-brand-700">
              {t(roleLabel)}
            </span>
          </span>
          <div className="flex items-center gap-1">
            <LanguageSwitcher compact />
            <button
              onClick={handleLogout}
              aria-label={t("Sign out")}
              className="rounded-lg p-2 text-slate-500 hover:bg-red-50 hover:text-red-600"
            >
              <NavIcon label="Sign out" className="h-5 w-5" />
            </button>
          </div>
        </header>

        {/* Desktop: language picker in the top-right corner, aligned with the page content. */}
        <div className="relative z-40 hidden px-8 pt-5 md:block">
          <div className="mx-auto flex max-w-6xl justify-end">
            <LanguageSwitcher />
          </div>
        </div>

        {/* Re-keyed on navigation so every page fades in. */}
        <main key={pathname} className="flex-1 animate-page p-4 pb-28 sm:p-6 md:p-8 md:pb-8 md:pt-2">
          <div className="mx-auto max-w-6xl">{children}</div>
        </main>

        {/* Mobile bottom nav */}
        <nav className="fixed inset-x-0 bottom-0 z-30 flex justify-around border-t border-slate-200 bg-white/90 px-2 pb-[env(safe-area-inset-bottom)] backdrop-blur md:hidden">
          {navItems.map((item) => {
            const active = item.href === current;
            return (
              <Link
                key={item.href}
                href={item.href}
                className={`relative flex min-w-0 flex-1 flex-col items-center gap-0.5 py-2 text-[10px] font-semibold ${
                  active ? "text-brand-600" : "text-slate-400"
                }`}
              >
                <span
                  className={`absolute top-0 h-0.5 rounded-full bg-brand-600 transition-all duration-300 ${
                    active ? "w-8" : "w-0"
                  }`}
                />
                <span className={`relative transition ${active ? "-translate-y-0.5 scale-110" : ""}`}>
                  <NavIcon label={item.label} className="h-5 w-5" />
                  {isCart(item.href) && (
                    <span className="absolute -right-3 -top-2">
                      <CartBadge />
                    </span>
                  )}
                </span>
                <span className="w-full truncate text-center">{t(item.label)}</span>
              </Link>
            );
          })}
        </nav>
      </div>
    </div>
  );
}
