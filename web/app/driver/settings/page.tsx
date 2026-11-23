import { createClient } from "@/lib/supabase/server";
import { getMyDriverProfile } from "@/lib/driver";
import { updateDriverProfile } from "../actions";
import ImageUploader from "@/components/ImageUploader";
import SavedToast from "@/components/SavedToast";
import { getT } from "@/lib/i18n/server";

export default async function DriverSettingsPage({
  searchParams,
}: {
  searchParams: { saved?: string };
}) {
  const driver = await getMyDriverProfile();
  if (!driver) return null;

  const t = getT();
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  const { data: profile } = await supabase
    .from("profiles")
    .select("full_name, phone, avatar_url")
    .eq("id", user!.id)
    .single();

  return (
    <div>
      {searchParams.saved === "1" && <SavedToast message={t("Saved successfully")} />}

      <h1 className="text-xl font-bold text-slate-900">{t("Settings")}</h1>
      <p className="mt-1 text-sm text-slate-500">
        {t("Your photo and phone number are shown to clients while you're delivering their order.")}
      </p>

      <div className="mt-6 max-w-lg space-y-4 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-slate-200">
        <div>
          <p className="mb-2 text-sm font-medium text-slate-700">{t("Profile photo")}</p>
          <ImageUploader
            label="photo"
            shape="circle"
            table="profiles"
            column="avatar_url"
            rowId={user!.id}
            currentUrl={profile?.avatar_url}
            storagePath={`avatars/${user!.id}/photo.jpg`}
          />
        </div>
      </div>

      <form
        action={updateDriverProfile}
        className="mt-4 max-w-lg space-y-4 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-slate-200"
      >
        <div>
          <label className="block text-sm font-medium text-slate-700">{t("Full name")}</label>
          <input
            name="full_name"
            defaultValue={profile?.full_name ?? ""}
            className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-slate-700">{t("Phone number")}</label>
          <input
            name="phone"
            type="tel"
            defaultValue={profile?.phone ?? ""}
            required
            className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-slate-700">{t("Vehicle type")}</label>
          <select
            name="vehicle_type"
            defaultValue={driver.vehicle_type ?? "bike"}
            className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
          >
            <option value="bike">{t("Bike")}</option>
            <option value="scooter">{t("Scooter")}</option>
            <option value="car">{t("Car")}</option>
          </select>
        </div>
        <div>
          <label className="block text-sm font-medium text-slate-700">{t("License plate")}</label>
          <input
            name="license_plate"
            defaultValue={driver.license_plate ?? ""}
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

      <div className="mt-4 max-w-lg rounded-2xl border border-amber-200 bg-amber-50 p-4 text-sm text-amber-800">
        💡 {t("Foodivo takes a 10% platform fee from your delivery earnings on each completed order.")}
      </div>
    </div>
  );
}
