"use client";

import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { useI18n } from "@/lib/i18n/client";
import { formatDate } from "@/lib/i18n/core";

const ROLE_TABS = [
  { key: "", emoji: "", label: "All" },
  { key: "client", emoji: "🧑", label: "Client" },
  { key: "restaurant_owner", emoji: "🍽️", label: "Restaurant owner" },
  { key: "driver", emoji: "🛵", label: "Driver" },
  { key: "admin", emoji: "🛡️", label: "Admin" },
];

export default function AdminUsersPage() {
  const { t, locale } = useI18n();
  const supabase = createClient();

  const [users, setUsers] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [role, setRole] = useState("");
  const [search, setSearch] = useState("");

  useEffect(() => {
    setLoading(true);
    let q = supabase
      .from("profiles")
      .select("*")
      .order("created_at", { ascending: false });
    if (role) q = q.eq("role", role);
    q.then(({ data }) => {
      setUsers(data ?? []);
      setLoading(false);
    });
  }, [role]);

  const shown = search.trim()
    ? users.filter((u) =>
        `${u.full_name ?? ""} ${u.phone ?? ""}`.toLowerCase().includes(search.trim().toLowerCase())
      )
    : users;

  return (
    <div>
      <h1 className="text-xl font-bold text-slate-900">{t("Users")}</h1>
      <p className="mt-1 text-sm text-slate-500">{t("Everyone registered on the platform.")}</p>

      {/* Role tabs */}
      <div className="mt-5 flex flex-wrap gap-1 rounded-xl bg-slate-100 p-1 w-fit">
        {ROLE_TABS.map((tab) => (
          <button
            key={tab.key}
            onClick={() => setRole(tab.key)}
            className={`rounded-lg px-3 py-1.5 text-sm font-medium transition ${
              role === tab.key
                ? "bg-white text-slate-900 shadow-sm"
                : "text-slate-500 hover:text-slate-700"
            }`}
          >
            {tab.emoji ? `${tab.emoji} ` : ""}{t(tab.label)}
          </button>
        ))}
      </div>

      {/* Search */}
      <div className="mt-3">
        <input
          type="search"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder={t("Search by name or phone…")}
          className="w-full max-w-sm rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm shadow-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
        />
      </div>

      {/* Table */}
      <div className="mt-4 overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-slate-200">
        {loading ? (
          <div className="flex items-center justify-center py-16 text-slate-400">{t("Loading…")}</div>
        ) : (
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
              {shown.map((u) => (
                <tr key={u.id} className="border-b border-slate-100 last:border-0">
                  <td className="px-4 py-3 font-medium text-slate-900">{u.full_name}</td>
                  <td className="px-4 py-3 text-slate-600">{u.phone ?? "—"}</td>
                  <td className="px-4 py-3">
                    <span className="rounded-full bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-600">
                      {t(ROLE_TABS.find((r) => r.key === u.role)?.label ?? u.role)}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-slate-500">{formatDate(locale, u.created_at)}</td>
                </tr>
              ))}
              {shown.length === 0 && (
                <tr>
                  <td colSpan={4} className="px-4 py-8 text-center text-slate-400">
                    {t("No users yet.")}
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        )}
      </div>

      {!loading && (
        <p className="mt-3 text-xs text-slate-400">
          {shown.length} {t("users")}
        </p>
      )}
    </div>
  );
}
