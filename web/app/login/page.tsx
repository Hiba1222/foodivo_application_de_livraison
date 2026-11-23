"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import AuthBackdrop from "@/components/AuthBackdrop";
import Logo from "@/components/Logo";
import { createClient } from "@/lib/supabase/client";
import { useI18n } from "@/lib/i18n/client";

export default function LoginPage() {
  const router = useRouter();
  const supabase = createClient();
  const { t } = useI18n();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleLogin(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);

    const { data, error: signInError } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (signInError) {
      setError(signInError.message);
      setLoading(false);
      return;
    }

    const { data: profile } = await supabase
      .from("profiles")
      .select("role")
      .eq("id", data.user.id)
      .single();

    const destinations: Record<string, string> = {
      admin: "/admin",
      restaurant_owner: "/restaurant",
      client: "/client",
      driver: "/driver",
    };

    router.replace(destinations[profile?.role ?? ""] ?? "/unauthorized");
    router.refresh();
  }

  return (
    <AuthBackdrop>
      <div className="w-full max-w-sm mx-auto rounded-3xl bg-white/85 p-8 shadow-lift ring-1 ring-white/60 backdrop-blur-xl">
        <div className="mb-4 flex animate-[pop_0.6s_0.2s_both] justify-center">
          <Logo className="h-20" />
        </div>
        <h1 className="text-3xl font-extrabold text-gradient">{t("Welcome back")}</h1>
        <p className="mt-1 text-sm text-slate-500">
          {t("Sign in — you'll be routed to your dashboard automatically.")}
        </p>

        <form onSubmit={handleLogin} className="mt-6 space-y-4">
          <div>
            <label className="block text-sm font-medium text-slate-700">
              {t("Email")}
            </label>
            <input
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:border-brand-500 focus:outline-none focus:ring-1 focus:ring-brand-500"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-slate-700">
              {t("Password")}
            </label>
            <input
              type="password"
              required
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
            {loading ? t("Signing in…") : t("Sign in")}
          </button>
        </form>

        <div className="mt-3 text-center">
          <Link href="/forgot-password" className="text-sm text-brand-600 hover:underline">
            {t("Forgot password?")}
          </Link>
        </div>

        <p className="mt-3 text-center text-sm text-slate-500">
          {t("No account yet?")}{" "}
          <Link href="/signup" className="font-medium text-brand-600">
            {t("Sign up")}
          </Link>
        </p>
      </div>
    </AuthBackdrop>
  );
}
