"use client";

import { useEffect, useState } from "react";
import Toast from "./Toast";

export default function SavedToast({ message = "Saved successfully" }: { message?: string }) {
  const [visible, setVisible] = useState(true);
  useEffect(() => {
    const t = setTimeout(() => setVisible(false), 2500);
    return () => clearTimeout(t);
  }, []);
  return visible ? <Toast>✓ {message}</Toast> : null;
}
