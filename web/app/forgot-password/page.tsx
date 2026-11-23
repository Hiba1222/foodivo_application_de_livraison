"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import AuthBackdrop from "@/components/AuthBackdrop";
import Logo from "@/components/Logo";
import { createClient } from "@/lib/supabase/client";
import { useI18n } from "@/lib/i18n/client";

type Step = "email" | "code" | "done";

export default function ForgotPasswordPage() {
  const { t } = useI18n();
  const router = useRouter();
  const supabase = createClient();

  const [step, setStep] = useState<Step>("email");
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [obscure, setObscure] = useState(true);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function sendCode(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      const res = await fetch("/api/forgot-password", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email: email.trim() }),
      });
      const json = await res.json();
      if (!res.ok) throw new Error(json.error ?? "Something went wrong");
      setStep("code");
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Something went wrong");
    } finally {
      setLoading(false);
    }
  }

  async function resetPassword(e: React.FormEvent) {
    e.preventDefault();
    if (password !== confirm) { setError(t("Passwords do not match.")); return; }
    if (password.length < 6) { setError(t("Password must be at least 6 characters")); return; }
    setLoading(true);
    setError(null);
    try {
      // Verify the OTP code — this establishes a session
      const { error: verifyErr } = await supabase.auth.verifyOtp({
        email: email.trim(),
        token: code.trim(),
        type: "recovery",
      });
      if (verifyErr) throw new Error(t("Invalid or expired code. Please request a new one."));

      // Set the new password
      const { error: updateErr } = await supabase.auth.updateUser({ password });
      if (updateErr) throw new Error(updateErr.message);

      setStep("done");
      setTimeout(() => router.replace("/login"), 3000);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Something went wrong");
    } finally {
      setLoading(false);
    }
  }

  return (
    <AuthBackdrop>
      <div className="w-full max-w-sm mx-auto rounded-3xl bg-white/85 p-8 shadow-lift ring-1 ring-white/60 backdrop-blur-xl">
        <div className="mb-4 flex justify-center">
          <Logo className="h-16" />
        </div>

        {step === "done" && (
          <div className="text-center">
            <div className="mb-4 text-5xl">✅</div>
            <h1 className="text-2xl font-extrabold text-slate-900">{t("Password updated!")}</h1>
            <p className="mt-3 text-sm text-slate-500">
              {t("Your password has been changed successfully. Redirecting you to sign in…")}
            </p>
          </div>
        )}

        {step === "email" && (
          <>
            <h1 className="text-2xl font-extrabold text-slate-900">{t("Forgot password?")}</h1>
            <p className="mt-2 text-sm text-slate-500">
              {t("Enter your email address and we'll send you a 6-digit code.")}
            </p>
            <form onSubmit={sendCode} className="mt-6 space-y-4">
              <div>
                <label className="block text-sm font-medium text-slate-700">{t("Email")}</label>
                <input
                  type="email" required autoFocus value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="you@example.com"
                  className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:border-brand-500 focus:outline-none focus:ring-1 focus:ring-brand-500"
                />
              </div>
              {error && <p className="text-sm text-red-600">{error}</p>}
              <button type="submit" disabled={loading} className="btn-primary w-full py-3">
                {loading ? t("Sending…") : t("Send code")}
              </button>
            </form>
            <div className="mt-4 text-center">
              <Link href="/login" className="text-sm text-brand-600 hover:underline">
                ← {t("Back to sign in")}
              </Link>
            </div>
          </>
        )}

        {step === "code" && (
          <>
            <h1 className="text-2xl font-extrabold text-slate-900">{t("Check your email")}</h1>
            <p className="mt-2 text-sm text-slate-500">
              {t("We sent a 6-digit code to")}{" "}
              <strong className="text-slate-700">{email}</strong>.{" "}
              {t("Enter it below with your new password.")}
            </p>
            <form onSubmit={resetPassword} className="mt-6 space-y-4">
              <div>
                <label className="block text-sm font-medium text-slate-700">{t("6-digit code")}</label>
                <input
                  type="text" required autoFocus inputMode="numeric"
                  maxLength={6} value={code}
                  onChange={(e) => setCode(e.target.value.replace(/\D/g, ""))}
                  placeholder="123456"
                  className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-3 text-center text-2xl font-bold tracking-[0.5em] focus:border-brand-500 focus:outline-none focus:ring-1 focus:ring-brand-500"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-700">{t("New password")}</label>
                <div className="relative mt-1">
                  <input
                    type={obscure ? "password" : "text"}
                    required value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    className="w-full rounded-lg border border-slate-300 px-3 py-2 pr-10 text-sm focus:border-brand-500 focus:outline-none focus:ring-1 focus:ring-brand-500"
                  />
                  <button type="button" onClick={() => setObscure(!obscure)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600">
                    {obscure ? "👁" : "🙈"}
                  </button>
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-700">{t("Confirm password")}</label>
                <input
                  type={obscure ? "password" : "text"}
                  required value={confirm}
                  onChange={(e) => setConfirm(e.target.value)}
                  className={`mt-1 w-full rounded-lg border px-3 py-2 text-sm focus:outline-none focus:ring-1 ${
                    confirm && confirm !== password
                      ? "border-red-400 focus:border-red-500 focus:ring-red-500"
                      : "border-slate-300 focus:border-brand-500 focus:ring-brand-500"
                  }`}
                />
                {confirm && confirm !== password && (
                  <p className="mt-1 text-xs text-red-500">{t("Passwords do not match.")}</p>
                )}
              </div>
              {error && <p className="text-sm text-red-600">{error}</p>}
              <button type="submit"
                disabled={loading || code.length < 6 || (!!confirm && confirm !== password)}
                className="btn-primary w-full py-3">
                {loading ? t("Saving…") : t("Set new password")}
              </button>
            </form>
            <div className="mt-3 text-center text-xs text-slate-400">
              {t("Didn't receive it? Check your spam folder or")}{" "}
              <button onClick={() => { setStep("email"); setCode(""); setError(null); }}
                className="text-brand-600 hover:underline">
                {t("try again")}
              </button>
            </div>
          </>
        )}
      </div>
    </AuthBackdrop>
  );
}
