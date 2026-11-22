"use client";

import { useEffect, useState } from "react";
import { createPortal } from "react-dom";

/** Small animated notification pinned to the bottom-centre of the screen. Unmount it to hide it. */
export default function Toast({ children }: { children: React.ReactNode }) {
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);
  if (!mounted) return null;

  return createPortal(
    <div
      role="status"
      className="fixed bottom-40 left-1/2 z-[60] flex animate-toast-in items-center gap-2 whitespace-nowrap rounded-full bg-slate-900 px-5 py-3 text-sm font-semibold text-white shadow-lift md:bottom-24"
    >
      {children}
    </div>,
    document.body
  );
}
