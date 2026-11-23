"use client";

import { useTransition } from "react";
import { cancelOrder } from "@/app/client/actions";
import { useI18n } from "@/lib/i18n/client";

export default function CancelOrderButton({ orderId }: { orderId: string }) {
  const { t } = useI18n();
  const [isPending, startTransition] = useTransition();

  function handleClick() {
    if (!confirm(t("Cancel this order? This cannot be undone."))) return;
    startTransition(() => cancelOrder(orderId));
  }

  return (
    <button
      onClick={handleClick}
      disabled={isPending}
      className="mt-4 w-full rounded-xl border border-red-300 bg-red-50 py-3 text-sm font-semibold text-red-700 hover:bg-red-100 disabled:opacity-50"
    >
      {isPending ? t("Cancelling…") : t("Cancel order")}
    </button>
  );
}
