import { createClient } from "@/lib/supabase/server";
import { setRestaurantApproval } from "@/app/admin/actions";
import type { Restaurant } from "@/lib/types";
import { getT } from "@/lib/i18n/server";
import type { TFn } from "@/lib/i18n/core";

async function getRestaurants(): Promise<Restaurant[]> {
  const supabase = createClient();
  const { data } = await supabase
    .from("restaurants")
    .select("*")
    .order("created_at", { ascending: false });
  return data ?? [];
}

function Badge({ approved, t }: { approved: boolean; t: TFn }) {
  return (
    <span
      className={`rounded-full px-2 py-0.5 text-xs font-semibold ${
        approved ? "bg-green-100 text-green-700" : "bg-amber-100 text-amber-700"
      }`}
    >
      {approved ? t("Approved") : t("Pending")}
    </span>
  );
}

export default async function AdminRestaurantsPage() {
  const t = getT();
  const restaurants = await getRestaurants();

  return (
    <div>
      <h1 className="text-xl font-bold text-slate-900">{t("Restaurants")}</h1>
      <p className="mt-1 text-sm text-slate-500">
        {t("Approve new restaurant signups, or suspend existing ones.")}
      </p>

      <div className="mt-6 overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-slate-200">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 bg-slate-50 text-slate-500">
            <tr>
              <th className="px-4 py-3 font-medium">{t("Name")}</th>
              <th className="px-4 py-3 font-medium">{t("Cuisine")}</th>
              <th className="px-4 py-3 font-medium">{t("Address")}</th>
              <th className="px-4 py-3 font-medium">{t("Status")}</th>
              <th className="px-4 py-3 font-medium">{t("Action")}</th>
            </tr>
          </thead>
          <tbody>
            {restaurants.map((r) => (
              <tr key={r.id} className="border-b border-slate-100 last:border-0">
                <td className="px-4 py-3 font-medium text-slate-900">{r.name}</td>
                <td className="px-4 py-3 text-slate-600">{r.cuisine_type ?? "—"}</td>
                <td className="px-4 py-3 text-slate-600">{r.address}</td>
                <td className="px-4 py-3">
                  <Badge approved={r.is_approved} t={t} />
                </td>
                <td className="px-4 py-3">
                  <form
                    action={setRestaurantApproval.bind(null, r.id, !r.is_approved)}
                  >
                    <button
                      type="submit"
                      className={`rounded-lg px-3 py-1.5 text-xs font-semibold ${
                        r.is_approved
                          ? "bg-red-50 text-red-700 hover:bg-red-100"
                          : "bg-brand-600 text-white hover:bg-brand-700"
                      }`}
                    >
                      {r.is_approved ? t("Suspend") : t("Approve")}
                    </button>
                  </form>
                </td>
              </tr>
            ))}
            {restaurants.length === 0 && (
              <tr>
                <td colSpan={5} className="px-4 py-8 text-center text-slate-400">
                  {t("No restaurants yet.")}
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
