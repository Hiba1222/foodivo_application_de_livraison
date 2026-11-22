"use client";

import { useRef, useState } from "react";
import { useI18n } from "@/lib/i18n/client";

export default function AddGroupForm({ action }: { action: (formData: FormData) => Promise<void> }) {
  const { t } = useI18n();
  const formRef = useRef<HTMLFormElement>(null);
  const [kind, setKind] = useState<"choice" | "ingredients">("choice");
  const [pending, setPending] = useState(false);

  return (
    <form
      ref={formRef}
      action={async (fd) => {
        setPending(true);
        try {
          await action(fd);
          formRef.current?.reset();
          setKind("choice");
        } finally {
          setPending(false);
        }
      }}
      className="space-y-4"
    >
      <div className="grid gap-2 sm:grid-cols-2">
        {[
          {
            value: "choice" as const,
            title: t("Choice list"),
            text: t("Customer picks from options — bread, size, sauces, paid add-ons."),
          },
          {
            value: "ingredients" as const,
            title: t("Ingredients"),
            text: t("What's in the meal — customer can choose No / Regular / Extra."),
          },
        ].map((k) => (
          <label
            key={k.value}
            className={`cursor-pointer rounded-xl border-2 p-3 text-sm ${
              kind === k.value ? "border-brand-600 bg-brand-50" : "border-slate-200 hover:border-slate-300"
            }`}
          >
            <input
              type="radio"
              name="kind"
              value={k.value}
              checked={kind === k.value}
              onChange={() => setKind(k.value)}
              className="sr-only"
            />
            <span className="block font-semibold text-slate-900">{k.title}</span>
            <span className="mt-0.5 block text-xs text-slate-500">{k.text}</span>
          </label>
        ))}
      </div>

      <input
        name="name"
        required
        placeholder={kind === "choice" ? t('Group name, e.g. "Choose your bread"') : t('Group name, e.g. "What\'s inside"')}
        className="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
      />

      {kind === "choice" && (
        <div className="flex flex-wrap items-center gap-4 text-sm">
          <label className="flex items-center gap-2 text-slate-700">
            <input type="checkbox" name="required" className="h-4 w-4" />
            {t("Customer must choose")}
          </label>
          <label className="flex items-center gap-2 text-slate-700">
            {t("How many can they pick?")}
            <select name="max_select" defaultValue="1" className="rounded-lg border border-slate-300 px-2 py-1.5 text-sm">
              <option value="1">{t("Only 1")}</option>
              <option value="2">{t("Up to {n}", { n: 2 })}</option>
              <option value="3">{t("Up to {n}", { n: 3 })}</option>
              <option value="4">{t("Up to {n}", { n: 4 })}</option>
              <option value="5">{t("Up to {n}", { n: 5 })}</option>
              <option value="">{t("No limit")}</option>
            </select>
          </label>
        </div>
      )}

      <button
        type="submit"
        disabled={pending}
        className="rounded-lg bg-slate-800 px-4 py-2 text-sm font-semibold text-white hover:bg-slate-900 disabled:opacity-50"
      >
        {pending ? t("Adding…") : t("Add group")}
      </button>
    </form>
  );
}
