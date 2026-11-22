"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import AuthBackdrop from "@/components/AuthBackdrop";
import Logo from "@/components/Logo";
import { createClient } from "@/lib/supabase/client";
import type { UserRole } from "@/lib/types";
import { useI18n } from "@/lib/i18n/client";

const ROLE_OPTIONS: { value: UserRole; label: string; blurb: string }[] = [
  { value: "client", label: "Client", blurb: "Order food for delivery" },
  { value: "restaurant_owner", label: "Restaurant", blurb: "Sell food on the platform" },
  { value: "driver", label: "Driver", blurb: "Deliver orders and earn" },
];

const ROLE_HOME: Record<UserRole, string> = {
  admin: "/admin",
  restaurant_owner: "/restaurant",
  client: "/client",
  driver: "/driver",
};

export default function SignupPage() {
  const router = useRouter();
  const supabase = createClient();
  const { t } = useI18n();

  const [role, setRole] = useState<UserRole>("client");
  const [fullName, setFullName] = useState("");
  const [phone, setPhone] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSignup(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);

    const { data, error: signUpError } = await supabase.auth.signUp({ email, password });

    if (signUpError) {
      setError(signUpError.message);
      setLoading(false);
      return;
    }

    if (!data.user || !data.session) {
      // Email confirmation is turned on for this Supabase project — the
      // account exists but isn't logged in yet, so we can't write their
      // profile row (RLS requires auth.uid() = id). See README: for this
      // project, turn "Confirm email" off in Supabase Auth settings so
      // signup logs the user in immediately.
      setError(
        t(
          "Account created, but email confirmation is required before you can continue. Check your inbox, or ask the project owner to disable email confirmation for development."
        )
      );
      setLoading(false);
      return;
    }

    const { error: profileError } = await supabase.from("profiles").insert({
      id: data.user.id,
      role,
      full_name: fullName,
      phone,
    });

    if (profileError) {
      setError(profileError.message);
      setLoading(false);
      return;
    }

    router.replace(ROLE_HOME[role]);
    router.refresh();
  }

  return (
    <AuthBackdrop>
      <div className="w-full max-w-sm mx-auto rounded-3xl bg-white/85 p-8 shadow-lift ring-1 ring-white/60 backdrop-blur-xl">
        <div className="mb-4 flex animate-[pop_0.6s_0.2s_both] justify-center">
          <Logo className="h-20" />
        </div>
        <h1 className="text-3xl font-extrabold text-gradient">{t("Create account")}</h1>
        <p className="mt-1 text-sm text-slate-500">
          {t("Restaurant and driver accounts need admin approval after signup.")}
        </p>

        <div className="mt-5 grid grid-cols-3 gap-2">
          {ROLE_OPTIONS.map((opt) => (
            <button
              key={opt.value}
              type="button"
              onClick={() => setRole(opt.value)}
              className={`rounded-lg border px-2 py-2 text-center text-xs font-semibold transition ${
                role === opt.value
                  ? "scale-105 border-brand-600 bg-brand-50 text-brand-700 shadow-md"
                  : "border-slate-200 text-slate-500 hover:border-slate-300"
              }`}
            >
              {t(opt.label)}
            </button>
          ))}
        </div>
        <p className="mt-2 text-center text-xs text-slate-400">
          {t(ROLE_OPTIONS.find((o) => o.value === role)?.blurb ?? "")}
        </p>

        <form onSubmit={handleSignup} className="mt-5 space-y-4">
          <div>
            <label className="block text-sm font-medium text-slate-700">{t("Full name")}</label>
            <input
              required
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:border-brand-500 focus:outline-none focus:ring-1 focus:ring-brand-500"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-slate-700">{t("Phone number")}</label>
            <input
              type="tel"
              required
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              placeholder="+216 20 123 456"
              className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:border-brand-500 focus:outline-none focus:ring-1 focus:ring-brand-500"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-slate-700">{t("Email")}</label>
            <input
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:border-brand-500 focus:outline-none focus:ring-1 focus:ring-brand-500"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-slate-700">{t("Password")}</label>
            <input
              type="password"
              required
              minLength={6}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:border-brand-500 focus:outline-none focus:ring-1 focus:ring-brand-500"
            />
          </div>

          {error && <p className="text-sm text-red-600">{error}</p>}

          <button
            type="submit"
            disabled={loading}
            className="btn-primary w-full py-3"
          >
            {loading ? t("Creating account…") : t("Create account")}
          </button>
        </form>

        <p className="mt-4 text-center text-sm text-slate-500">
          {t("Already have an account?")}{" "}
          <Link href="/login" className="font-medium text-brand-600">
            {t("Sign in")}
          </Link>
        </p>
      </div>
    </AuthBackdrop>
  );
}
