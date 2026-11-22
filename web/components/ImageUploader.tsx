"use client";

import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { useI18n } from "@/lib/i18n/client";

/**
 * Upload an image to the `media` storage bucket at `storagePath`, then
 * write the resulting public URL into `table.column` for the row with
 * id = `rowId`. Relies on the same Row Level Security policies that
 * already protect that table (e.g. a restaurant owner can only update
 * their own restaurant) — this component doesn't bypass anything.
 */
export default function ImageUploader({
  storagePath,
  table,
  column,
  rowId,
  currentUrl,
  label,
  shape = "square",
}: {
  storagePath: string;
  table: string;
  column: string;
  rowId: string;
  currentUrl?: string | null;
  label: string;
  shape?: "square" | "circle" | "wide";
}) {
  const router = useRouter();
  const supabase = createClient();
  const inputRef = useRef<HTMLInputElement>(null);
  const { t } = useI18n();
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(currentUrl ?? null);

  async function handleFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;

    setUploading(true);
    setError(null);

    const { error: uploadError } = await supabase.storage
      .from("media")
      .upload(storagePath, file, { upsert: true, cacheControl: "3600" });

    if (uploadError) {
      setError(uploadError.message);
      setUploading(false);
      return;
    }

    const {
      data: { publicUrl },
    } = supabase.storage.from("media").getPublicUrl(storagePath);
    // Cache-bust so the new photo shows immediately even though the path
    // (and therefore the base URL) didn't change.
    const bustedUrl = `${publicUrl}?t=${Date.now()}`;

    const { error: dbError } = await supabase
      .from(table)
      .update({ [column]: bustedUrl })
      .eq("id", rowId);

    if (dbError) {
      setError(dbError.message);
      setUploading(false);
      return;
    }

    setPreviewUrl(bustedUrl);
    setUploading(false);
    router.refresh();
  }

  const shapeClass =
    shape === "circle" ? "rounded-full" : shape === "wide" ? "rounded-xl aspect-[3/1]" : "rounded-xl aspect-square";

  return (
    <div className="flex items-center gap-3">
      <div
        className={`flex h-16 w-16 shrink-0 items-center justify-center overflow-hidden bg-slate-100 text-xs text-slate-400 ${shapeClass} ${
          shape === "wide" ? "h-16 w-28" : ""
        }`}
      >
        {previewUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={previewUrl} alt={label} className="h-full w-full object-cover" />
        ) : (
          t("No photo")
        )}
      </div>
      <div>
        <button
          type="button"
          onClick={() => inputRef.current?.click()}
          disabled={uploading}
          className="rounded-lg bg-slate-800 px-3 py-1.5 text-xs font-semibold text-white hover:bg-slate-900 disabled:opacity-50"
        >
          {/* Full-phrase keys ("Add photo", "Change logo"…) translate better than "Add {label}". */}
          {uploading ? t("Uploading…") : t(previewUrl ? `Change ${label}` : `Add ${label}`)}
        </button>
        {error && <p className="mt-1 text-xs text-red-600">{error}</p>}
      </div>
      <input
        ref={inputRef}
        type="file"
        accept="image/*"
        className="hidden"
        onChange={handleFileChange}
      />
    </div>
  );
}
