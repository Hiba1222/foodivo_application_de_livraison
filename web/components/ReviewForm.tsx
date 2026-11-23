"use client";

import { useState, useTransition } from "react";
import { submitReview } from "@/app/client/actions";
import { useI18n } from "@/lib/i18n/client";

function Stars({ value, onChange }: { value: number; onChange: (n: number) => void }) {
  return (
    <div className="flex gap-0.5">
      {[1, 2, 3, 4, 5].map((n) => (
        <button
          key={n}
          type="button"
          onClick={() => onChange(n)}
          className="text-2xl leading-none transition-transform hover:scale-110"
        >
          {n <= value ? "⭐" : "☆"}
        </button>
      ))}
    </div>
  );
}

export default function ReviewForm({
  orderId,
  hasDriver,
}: {
  orderId: string;
  hasDriver: boolean;
}) {
  const { t } = useI18n();
  const [isPending, startTransition] = useTransition();
  const [submitted, setSubmitted] = useState(false);
  const [restaurantRating, setRestaurantRating] = useState(0);
  const [driverRating, setDriverRating] = useState(0);
  const [comment, setComment] = useState("");
  const [error, setError] = useState<string | null>(null);

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (restaurantRating === 0) {
      setError(t("Please rate the restaurant."));
      return;
    }
    setError(null);
    startTransition(async () => {
      try {
        await submitReview({
          orderId,
          restaurantRating,
          driverRating: hasDriver && driverRating > 0 ? driverRating : null,
          comment: comment.trim() || null,
        });
        setSubmitted(true);
      } catch (err) {
        setError(err instanceof Error ? err.message : t("Something went wrong"));
      }
    });
  }

  if (submitted) {
    return (
      <div className="mt-4 rounded-2xl bg-green-50 p-5 text-center ring-1 ring-green-200">
        <p className="text-3xl">⭐</p>
        <p className="mt-1 text-sm font-semibold text-green-700">{t("Thanks for your review!")}</p>
      </div>
    );
  }

  return (
    <form
      onSubmit={handleSubmit}
      className="mt-4 rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200"
    >
      <h2 className="text-sm font-semibold text-slate-900">{t("Rate your order")}</h2>
      <div className="mt-3 space-y-4">
        <div>
          <p className="mb-1 text-xs font-medium text-slate-500">{t("Restaurant")}</p>
          <Stars value={restaurantRating} onChange={setRestaurantRating} />
        </div>
        {hasDriver && (
          <div>
            <p className="mb-1 text-xs font-medium text-slate-500">{t("Driver")}</p>
            <Stars value={driverRating} onChange={setDriverRating} />
          </div>
        )}
        <textarea
          value={comment}
          onChange={(e) => setComment(e.target.value)}
          placeholder={t("Leave a comment (optional)")}
          rows={2}
          maxLength={500}
          className="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:border-brand-500 focus:outline-none focus:ring-1 focus:ring-brand-500"
        />
      </div>
      {error && <p className="mt-2 text-sm text-red-600">{error}</p>}
      <button
        type="submit"
        disabled={isPending}
        className="btn-primary mt-3 w-full py-2.5"
      >
        {isPending ? t("Submitting…") : t("Submit review")}
      </button>
    </form>
  );
}
