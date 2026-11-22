import { createClient } from "@/lib/supabase/server";
import type { Profile } from "@/lib/types";
import { getLocale, getT } from "@/lib/i18n/server";
import { formatDate } from "@/lib/i18n/core";

async function getUsers(): Promise<Profile[]> {
  const supabase = createClient();
  const { data } = await supabase
    .from("profiles")
    .select("*")
    .order("created_at", { ascending: false });
  return data ?? [];
}

// English keys — translated with t() at render time.
const ROLE_LABEL: Record<string, string> = {
  admin: "Admin",
  restaurant_owner: "Restaurant owner",
  client: "Client",
  driver: "Driver",
};

export default async function AdminUsersPage() {
  const t = getT();
  const locale = getLocale();
  const users = await getUsers();

  return (
    <div>
      <h1 className="text-xl font-bold text-slate-900">{t("Users")}</h1>
      <p className="mt-1 text-sm text-slate-500">{t("Everyone registered on the platform.")}</p>

      <div className="mt-6 overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-slate-200">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 bg-slate-50 text-slate-500">
            <tr>
              <th className="px-4 py-3 font-medium">{t("Name")}</th>
              <th className="px-4 py-3 font-medium">{t("Phone")}</th>
              <th className="px-4 py-3 font-medium">{t("Role")}</th>
              <th className="px-4 py-3 font-medium">{t("Joined")}</th>
            </tr>
          </thead>
          <tbody>
            {users.map((u) => (
              <tr key={u.id} className="border-b border-slate-100 last:border-0">
                <td className="px-4 py-3 font-medium text-slate-900">{u.full_name}</td>
                <td className="px-4 py-3 text-slate-600">{u.phone ?? "—"}</td>
                <td className="px-4 py-3 text-slate-600">{t(ROLE_LABEL[u.role] ?? u.role)}</td>
                <td className="px-4 py-3 text-slate-500">
                  {formatDate(locale, u.created_at)}
                </td>
              </tr>
            ))}
            {users.length === 0 && (
              <tr>
                <td colSpan={4} className="px-4 py-8 text-center text-slate-400">
                  {t("No users yet.")}
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
