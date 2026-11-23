"use client";

import { Suspense, useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import Link from "next/link";
import AuthBackdrop from "@/components/AuthBackdrop";
import Logo from "@/components/Logo";
import { createClient } from "@/lib/supabase/client";
import { useI18n } from "@/lib/i18n/client";

function ResetPasswordForm() {
  const { t } = useI18n();
  const router = useRouter();
  const searchParams = useSearchParams();
  const supabase = createClient();

  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [obscure, setObscure] = useState(true);
  const [loading, setLoading] = useState(false);
  const [verifying, setVerifying] = useState(true);
  const [done, setDone] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const tokenHash = searchParams.get("token_hash");
    const type = searchParams.get("type");

    if (tokenHash && type === "recovery") {
      supabase.auth
        .verifyOtp({ token_hash: tokenHash, type: "recovery" })
        .then(({ error: err }) => {
          if (err) setError(t("This reset link is invalid or has expired. Please request a new one."));
          setVerifying(false);
        });
    } else {
      supabase.auth.getSession().then(({ data }) => {
        if (!data.session) {
          setError(t("This reset link is invalid or has expired. Please request a new one."));
        }
        setVerifying(false);
      });
    }
  }, []);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (password !== confirm) { setError(t("Passwords do not match.")); return; }
    if (password.length < 6) { setError(t("Password must be at least 6 characters")); return; }
    setLoading(true);
    setError(null);
    const { error: err } = await supabase.auth.updateUser({ password });
    setLoading(false);
    if (err) { setError(err.message); } else { setDone(true); setTimeout(() => router.replace("/login"), 3000); }
  }

  if (done) return (
    <div className="text-center">
      <div className="mb-4 text-5xl">✅</div>
      <h1 className="text-2xl font-extrabold text-slate-900">{t("Password updated!")}</h1>
      <p className="mt-3 text-sm text-slate-500">{t("Your password has been changed successfully. Redirecting you to sign in…")}</p>
    </div>
  );

  if (verifying) return (
    <div className="flex flex-col items-center gap-4 py-8">
      <div className="h-8 w-8 animate-spin rounded-full border-4 border-brand-500 border-t-transparent" />
      <p className="text-sm text-slate-500">{t("Verifying reset link…")}</p>
    </div>
  );

  if (error && !password) return (
    <div className="text-center">
      <div className="mb-4 text-5xl">❌</div>
      <h1 className="text-xl font-bold text-slate-900">{t("Link expired")}</h1>
      <p className="mt-3 text-sm text-slate-500">{error}</p>
      <Link href="/forgot-password" className="mt-6 inline-block rounded-xl bg-brand-600 px-6 py-2.5 text-sm font-semibold text-white hover:bg-brand-700">
        {t("Request a new link")}
      </Link>
    </div>
  );

  return (
    <>
      <h1 className="text-2xl font-extrabold text-slate-900">{t("Set new password")}</h1>
      <p className="mt-2 text-sm text-slate-500">{t("Choose a strong password of at least 6 characters.")}</p>
      <form onSubmit={handleSubmit} className="mt-6 space-y-4">
        <div>
          <label className="block text-sm font-medium text-slate-700">{t("New password")}</label>
          <div className="relative mt-1">
            <input
              type={obscure ? "password" : "text"}
              required autoFocus value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full rounded-lg border border-slate-300 px-3 py-2 pr-10 text-sm focus:border-brand-500 focus:outline-none focus:ring-1 focus:ring-brand-500"
            />
            <button type="button" onClick={() => setObscure(!obscure)} className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600">
              {obscure ? "👁" : "🙈"}
            </button>
          </div>
          {password.length > 0 && (
            <div className="mt-1.5 flex gap-1">
              {[1, 2, 3, 4].map((i) => (
                <div key={i} className={`h-1 flex-1 rounded-full transition-colors ${
                  password.length >= i * 3 ? (password.length >= 12 ? "bg-green-500" : password.length >= 8 ? "bg-amber-400" : "bg-red-400") : "bg-slate-200"
                }`} />
              ))}
            </div>
          )}
        </div>
        <div>
          <label className="block text-sm font-medium text-slate-700">{t("Confirm password")}</label>
          <input
            type={obscure ? "password" : "text"}
            required value={confirm}
            onChange={(e) => setConfirm(e.target.value)}
            className={`mt-1 w-full rounded-lg border px-3 py-2 text-sm focus:outline-none focus:ring-1 ${
              confirm && confirm !== password ? "border-red-400 focus:border-red-500 focus:ring-red-500" : "border-slate-300 focus:border-brand-500 focus:ring-brand-500"
            }`}
          />
          {confirm && confirm !== password && <p className="mt-1 text-xs text-red-500">{t("Passwords do not match.")}</p>}
        </div>
        {error && <p className="text-sm text-red-600">{error}</p>}
        <button type="submit" disabled={loading || (!!confirm && confirm !== password)} className="btn-primary w-full py-3">
          {loading ? t("Saving…") : t("Set new password")}
        </button>
      </form>
    </>
  );
}

export default function ResetPasswordPage() {
  return (
    <AuthBackdrop>
      <div className="w-full max-w-sm mx-auto rounded-3xl bg-white/85 p-8 shadow-lift ring-1 ring-white/60 backdrop-blur-xl">
        <div className="mb-4 flex justify-center">
          <Logo className="h-16" />
        </div>
        <Suspense fallback={
          <div className="flex flex-col items-center gap-4 py-8">
            <div className="h-8 w-8 animate-spin rounded-full border-4 border-brand-500 border-t-transparent" />
          </div>
        }>
          <ResetPasswordForm />
        </Suspense>
      </div>
    </AuthBackdrop>
  );
}
