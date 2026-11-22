"use client";

import { useCallback, useState } from "react";
import ItemCustomizer, { type CustomizerItem } from "@/components/ItemCustomizer";
import type { MenuOptionGroup } from "@/lib/menu-options";
import { useI18n } from "@/lib/i18n/client";

export default function PreviewButton({
  item,
  groups,
}: {
  item: CustomizerItem;
  groups: MenuOptionGroup[];
}) {
  const { t } = useI18n();
  const [open, setOpen] = useState(false);
  const close = useCallback(() => setOpen(false), []);

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="rounded-lg bg-white px-4 py-2 text-sm font-semibold text-slate-800 ring-1 ring-slate-300 hover:bg-slate-50"
      >
        {t("Preview as customer")}
      </button>
      {open && <ItemCustomizer item={item} groups={groups} onClose={close} />}
    </>
  );
}
