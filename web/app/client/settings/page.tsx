import { createClient } from "@/lib/supabase/server";
import ImageUploader from "@/components/ImageUploader";
import SavedToast from "@/components/SavedToast";
import {
  updateClientProfile,
  addAddress,
  deleteAddress,
  setDefaultAddress,
} from "../actions";
import { getT } from "@/lib/i18n/server";

export default async function ClientSettingsPage({
  searchParams,
}: {
  searchParams: { saved?: string };
}) {
  const t = getT();
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const [{ data: profile }, { data: addresses }] = await Promise.all([
    supabase.from("profiles").select("full_name, phone, avatar_url").eq("id", user!.id).single(),
    supabase
      .from("client_addresses")
      .select("id, label, address_line, is_default")
      .eq("client_id", user!.id)
      .order("is_default", { ascending: false }),
  ]);

  return (
    <div>
      {searchParams.saved === "1" && <SavedToast message={t("Saved successfully")} />}

      <h1 className="text-xl font-bold text-slate-900">{t("Settings")}</h1>

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
        action={updateClientProfile}
        className="mt-4 max-w-lg space-y-3 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-slate-200"
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
            className="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
          />
        </div>
        <button
          type="submit"
          className="rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white hover:bg-brand-700"
        >
          {t("Save changes")}
        </button>
      </form>

      <div className="mt-4 max-w-lg rounded-2xl bg-white p-6 shadow-sm ring-1 ring-slate-200">
        <h2 className="text-sm font-semibold text-slate-900">{t("Delivery addresses")}</h2>

        <div className="mt-3 space-y-2">
          {(addresses ?? []).map((addr) => (
            <div
              key={addr.id}
              className="flex items-center justify-between rounded-xl border border-slate-100 p-3 text-sm"
            >
              <div>
                <p className="font-medium text-slate-900">
                  {addr.label} {addr.is_default && <span className="text-xs text-brand-600">({t("default")})</span>}
                </p>
                <p className="text-slate-500">{addr.address_line}</p>
              </div>
              <div className="flex gap-2">
                {!addr.is_default && (
                  <form action={setDefaultAddress.bind(null, addr.id)}>
                    <button type="submit" className="text-xs font-semibold text-brand-600">
                      {t("Set default")}
                    </button>
                  </form>
                )}
                <form action={deleteAddress.bind(null, addr.id)}>
                  <button type="submit" className="text-xs font-semibold text-red-600">
                    {t("Delete")}
                  </button>
                </form>
              </div>
            </div>
          ))}
          {(addresses ?? []).length === 0 && (
            <p className="text-sm text-slate-400">{t("No addresses saved yet.")}</p>
          )}
        </div>

        <form action={addAddress} className="mt-4 space-y-2 border-t border-slate-100 pt-4">
          <p className="text-sm font-medium text-slate-700">{t("Add a new address")}</p>
          <input
            name="label"
            placeholder={t("Label (e.g. Home, Work)")}
            className="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
          />
          <input
            name="address_line"
            required
            placeholder={t("Full address")}
            className="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
          />
          <label className="flex items-center gap-2 text-xs text-slate-500">
            <input type="checkbox" name="is_default" /> {t("Set as default")}
          </label>
          <button
            type="submit"
            className="rounded-lg bg-slate-800 px-3 py-1.5 text-xs font-semibold text-white"
          >
            {t("Add address")}
          </button>
        </form>
      </div>
    </div>
  );
}
