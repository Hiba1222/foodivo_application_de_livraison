import { completeClientProfile } from "./actions";
import { getT } from "@/lib/i18n/server";

export default function CompleteProfileForm({
  needsPhone,
  needsAddress,
}: {
  needsPhone: boolean;
  needsAddress: boolean;
}) {
  const t = getT();
  return (
    <div className="flex min-h-[60vh] items-center justify-center px-4">
      <div className="w-full max-w-md rounded-2xl bg-white p-8 shadow-sm ring-1 ring-slate-200">
        <h1 className="text-xl font-bold text-slate-900">{t("Just one more thing")}</h1>
        <p className="mt-1 text-sm text-slate-500">
          {needsAddress && needsPhone
            ? t("We need your phone number and a delivery address before you can order.")
            : needsAddress
            ? t("Add a delivery address to start ordering.")
            : t("Add your phone number so drivers and restaurants can reach you.")}
        </p>

        <form action={completeClientProfile} className="mt-6 space-y-4">
          {needsPhone && (
            <div>
              <label className="block text-sm font-medium text-slate-700">{t("Phone number")}</label>
              <input
                name="phone"
                type="tel"
                required
                className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
              />
            </div>
          )}
          {needsAddress && (
            <>
              <div>
                <label className="block text-sm font-medium text-slate-700">{t("Label")}</label>
                <input
                  name="label"
                  placeholder={t("Home")}
                  defaultValue={t("Home")}
                  className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-700">{t("Delivery address")}</label>
                <input
                  name="address_line"
                  required
                  className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
                />
              </div>
            </>
          )}
          <button
            type="submit"
            className="w-full rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white hover:bg-brand-700"
          >
            {t("Continue")}
          </button>
        </form>
      </div>
    </div>
  );
}
