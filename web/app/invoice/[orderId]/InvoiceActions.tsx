"use client";
import { useState, useTransition } from "react";
import { emailInvoice } from "./actions";

export default function InvoiceActions({ orderId }: { orderId: string }) {
  const [pending, startTransition] = useTransition();
  const [sent, setSent] = useState(false);

  return (
    <div className="flex gap-2">
      <button
        onClick={() => window.print()}
        className="rounded-lg bg-brand-600 px-4 py-2 text-sm font-medium text-white hover:bg-brand-700 active:bg-brand-800"
      >
        🖨️ Print / Save PDF
      </button>
      <button
        disabled={pending || sent}
        onClick={() =>
          startTransition(async () => {
            await emailInvoice(orderId);
            setSent(true);
          })
        }
        className="rounded-lg bg-white px-4 py-2 text-sm font-medium text-slate-700 ring-1 ring-slate-200 hover:bg-slate-50 disabled:opacity-50"
      >
        {sent ? "✓ Sent!" : pending ? "Sending…" : "📧 Email to me"}
      </button>
    </div>
  );
}
