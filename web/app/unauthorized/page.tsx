import { getT } from "@/lib/i18n/server";

export default function UnauthorizedPage() {
  const t = getT();
  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-2 text-center">
      <h1 className="text-xl font-bold text-slate-900">{t("Not authorized")}</h1>
      <p className="text-sm text-slate-500">
        {t("Your account doesn't have access to this section.")}
      </p>
      <a href="/login" className="mt-4 text-sm font-medium text-brand-600">
        {t("Back to login")}
      </a>
    </div>
  );
}
