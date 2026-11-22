import { createRestaurant } from "./actions";
import { getT } from "@/lib/i18n/server";

export default function CreateRestaurantForm() {
  const t = getT();
  return (
    <div className="mx-auto w-full max-w-md animate-scale-in rounded-3xl bg-white p-8 shadow-lift ring-1 ring-slate-200/70">
      <h1 className="text-xl font-bold text-slate-900">{t("Set up your restaurant")}</h1>
      <p className="mt-1 text-sm text-slate-500">
        {t("One more step before you can manage your menu and orders.")}
      </p>

      <form action={createRestaurant} className="mt-6 space-y-4">
        <div>
          <label className="block text-sm font-medium text-slate-700">{t("Restaurant name")}</label>
          <input
            name="name"
            required
            className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-slate-700">{t("Cuisine type")}</label>
          <input
            name="cuisine_type"
            placeholder={t("Italian, Lebanese, Burgers…")}
            className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-slate-700">{t("Description")}</label>
          <textarea
            name="description"
            rows={2}
            className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-slate-700">{t("Address")}</label>
          <input
            name="address"
            required
            className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-slate-700">{t("Phone number")}</label>
          <input
            name="phone"
            type="tel"
            required
            className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
          />
        </div>
        <button
          type="submit"
          className="w-full rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white hover:bg-brand-700"
        >
          {t("Create restaurant")}
        </button>
      </form>
    </div>
  );
}
