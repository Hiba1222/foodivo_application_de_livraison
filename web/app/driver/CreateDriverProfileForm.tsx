import { createDriverProfile } from "./actions";
import { getT } from "@/lib/i18n/server";

export default function CreateDriverProfileForm() {
  const t = getT();
  return (
    <div className="mx-auto w-full max-w-md animate-scale-in rounded-3xl bg-white p-8 shadow-lift ring-1 ring-slate-200/70">
      <h1 className="text-xl font-bold text-slate-900">{t("Set up your driver profile")}</h1>
      <p className="mt-1 text-sm text-slate-500">
        {t("One more step before you can start accepting deliveries.")}
      </p>

      <form action={createDriverProfile} className="mt-6 space-y-4">
        <div>
          <label className="block text-sm font-medium text-slate-700">{t("Vehicle type")}</label>
          <select
            name="vehicle_type"
            required
            className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
          >
            <option value="bike">{t("Bike")}</option>
            <option value="scooter">{t("Scooter")}</option>
            <option value="car">{t("Car")}</option>
          </select>
        </div>
        <div>
          <label className="block text-sm font-medium text-slate-700">
            {t("License plate (if applicable)")}
          </label>
          <input
            name="license_plate"
            className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-slate-700">{t("Phone number")}</label>
          <input
            name="phone"
            type="tel"
            required
            placeholder={t("So clients and the restaurant can reach you")}
            className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
          />
        </div>
        <button
          type="submit"
          className="w-full rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white hover:bg-brand-700"
        >
          {t("Submit for approval")}
        </button>
      </form>
    </div>
  );
}
