import { getMyRestaurant } from "@/lib/restaurant";
import { updateRestaurant } from "../actions";
import ImageUploader from "@/components/ImageUploader";
import { getT } from "@/lib/i18n/server";

export default async function RestaurantSettingsPage() {
  const restaurant = await getMyRestaurant();
  if (!restaurant) return null;
  const t = getT();

  return (
    <div>
      <h1 className="text-xl font-bold text-slate-900">{t("Settings")}</h1>
      <p className="mt-1 text-sm text-slate-500">{t("Update your restaurant's public profile.")}</p>

      <div className="mt-6 max-w-lg space-y-4 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-slate-200">
        <div>
          <p className="mb-2 text-sm font-medium text-slate-700">{t("Logo")}</p>
          <ImageUploader
            label="logo"
            shape="circle"
            table="restaurants"
            column="logo_url"
            rowId={restaurant.id}
            currentUrl={restaurant.logo_url}
            storagePath={`restaurants/${restaurant.id}/logo.jpg`}
          />
        </div>
        <div>
          <p className="mb-2 text-sm font-medium text-slate-700">
            {t("Cover photo — shown to clients browsing restaurants")}
          </p>
          <ImageUploader
            label="cover photo"
            shape="wide"
            table="restaurants"
            column="cover_image_url"
            rowId={restaurant.id}
            currentUrl={restaurant.cover_image_url}
            storagePath={`restaurants/${restaurant.id}/cover.jpg`}
          />
        </div>
      </div>

      <form
        action={updateRestaurant.bind(null, restaurant.id)}
        className="mt-4 max-w-lg space-y-4 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-slate-200"
      >
        <div>
          <label className="block text-sm font-medium text-slate-700">{t("Name")}</label>
          <input
            name="name"
            defaultValue={restaurant.name}
            required
            className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-slate-700">{t("Cuisine type")}</label>
          <input
            name="cuisine_type"
            defaultValue={restaurant.cuisine_type ?? ""}
            className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-slate-700">{t("Description")}</label>
          <textarea
            name="description"
            defaultValue={restaurant.description ?? ""}
            rows={3}
            className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-slate-700">{t("Address")}</label>
          <input
            name="address"
            defaultValue={restaurant.address}
            required
            className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-slate-700">{t("Phone number")}</label>
          <input
            name="phone"
            type="tel"
            defaultValue={restaurant.phone ?? ""}
            required
            className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
          />
        </div>
        <button
          type="submit"
          className="rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white hover:bg-brand-700"
        >
          {t("Save changes")}
        </button>
      </form>
    </div>
  );
}
