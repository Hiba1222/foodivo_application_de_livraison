"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { createPortal } from "react-dom";
import {
  describeSelection,
  evaluateSelections,
  formatPrice,
  groupRuleText,
  isRequired,
  type MenuOptionGroup,
  type OptionSelection,
  type PricedSelection,
} from "@/lib/menu-options";
import { useI18n } from "@/lib/i18n/client";

export interface CustomizerItem {
  id: string;
  name: string;
  description: string | null;
  /** Base price to charge (offer already applied). */
  price_cents: number;
  /** Normal price when the item is on offer — shown struck through. */
  original_price_cents?: number | null;
  offer_label?: string | null;
  image_url?: string | null;
}

export interface CustomizedLine {
  selections: OptionSelection[];
  priced: PricedSelection[];
  unitPriceCents: number;
  quantity: number;
  notes: string;
}

type Level = "remove" | "regular" | "extra";

export default function ItemCustomizer({
  item,
  groups,
  onClose,
  onAdd,
}: {
  item: CustomizerItem;
  /** Already sorted, unavailable options removed. */
  groups: MenuOptionGroup[];
  onClose: () => void;
  /** Omit for preview mode (restaurant side). */
  onAdd?: (line: CustomizedLine) => void;
}) {
  const [chosen, setChosen] = useState<Record<string, string[]>>(() => {
    const init: Record<string, string[]> = {};
    for (const g of groups) {
      if (g.kind !== "choice") continue;
      const defaults = g.menu_options.filter((o) => o.is_default).map((o) => o.id);
      init[g.id] = g.max_select === null ? defaults : defaults.slice(0, g.max_select);
    }
    return init;
  });
  const [levels, setLevels] = useState<Record<string, Level>>({});
  const [notes, setNotes] = useState("");
  const [quantity, setQuantity] = useState(1);
  const [showErrors, setShowErrors] = useState(false);
  const groupRefs = useRef<Record<string, HTMLElement | null>>({});
  const { t } = useI18n();
  const [mounted, setMounted] = useState(false);
  const [shake, setShake] = useState(0);
  useEffect(() => setMounted(true), []);

  // Close on Escape + lock background scroll while open.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    document.addEventListener("keydown", onKey);
    const prevOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = prevOverflow;
    };
  }, [onClose]);

  const selections = useMemo<OptionSelection[]>(() => {
    const out: OptionSelection[] = [];
    for (const ids of Object.values(chosen)) for (const id of ids) out.push({ optionId: id, mode: "add" });
    for (const [id, level] of Object.entries(levels)) {
      if (level !== "regular") out.push({ optionId: id, mode: level });
    }
    return out;
  }, [chosen, levels]);

  const evaluation = useMemo(
    () => evaluateSelections(item.price_cents, groups, selections, t),
    [item.price_cents, groups, selections, t]
  );
  const hasErrors = Object.keys(evaluation.groupErrors).length > 0;
  const totalCents = evaluation.unitPriceCents * quantity;

  function toggleChoice(group: MenuOptionGroup, optionId: string) {
    setChosen((prev) => {
      const current = prev[group.id] ?? [];
      const isOn = current.includes(optionId);
      let next: string[];
      if (group.max_select === 1) {
        // Radio behaviour; optional single-choice groups can be un-ticked.
        next = isOn ? (group.min_select === 0 ? [] : current) : [optionId];
      } else if (isOn) {
        next = current.filter((id) => id !== optionId);
      } else if (group.max_select !== null && current.length >= group.max_select) {
        next = current;
      } else {
        next = [...current, optionId];
      }
      return { ...prev, [group.id]: next };
    });
  }

  function handleAdd() {
    if (!onAdd) return;
    if (hasErrors) {
      setShowErrors(true);
      setShake((n) => n + 1);
      const firstBad = groups.find((g) => evaluation.groupErrors[g.id]);
      if (firstBad) groupRefs.current[firstBad.id]?.scrollIntoView({ behavior: "smooth", block: "center" });
      return;
    }
    onAdd({
      selections,
      priced: evaluation.priced,
      unitPriceCents: evaluation.unitPriceCents,
      quantity,
      notes: notes.trim(),
    });
  }

  const summary = evaluation.priced.map((p) => describeSelection(p.mode, p.optionName, t));

  if (!mounted) return null;

  // Portal to <body> so no transformed/animated ancestor can break position:fixed.
  return createPortal(
    <div
      className="fixed inset-0 z-50 flex animate-fade-in items-end justify-center bg-slate-900/60 backdrop-blur-sm sm:items-center sm:p-4"
      onClick={onClose}
      role="dialog"
      aria-modal="true"
      aria-label={item.name}
    >
      <div
        className="flex max-h-[92vh] w-full max-w-lg animate-sheet-up flex-col overflow-hidden rounded-t-3xl bg-white shadow-2xl sm:animate-scale-in sm:rounded-3xl"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Scrollable body */}
        <div className="flex-1 overflow-y-auto">
          <div className="relative">
            {item.image_url ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={item.image_url} alt={item.name} className="h-56 w-full animate-[scale-in_0.8s_ease-out_both] object-cover" />
            ) : (
              <div className="h-14" />
            )}
            <button
              onClick={onClose}
              aria-label={t("Close")}
              className="absolute left-3 top-3 flex h-9 w-9 items-center justify-center rounded-full bg-white/90 text-lg font-semibold text-slate-700 shadow ring-1 ring-slate-200 backdrop-blur hover:rotate-90 hover:bg-white"
            >
              ✕
            </button>
          </div>

          <div className="px-5 pb-2 pt-4">
            <h2 className="text-2xl font-bold text-slate-900">{item.name}</h2>
            {item.original_price_cents && item.original_price_cents > item.price_cents ? (
              <div className="mt-1 flex flex-wrap items-center gap-2">
                <span className="text-lg font-extrabold text-rose-600">{formatPrice(item.price_cents)}</span>
                <span className="text-sm text-slate-400 line-through">{formatPrice(item.original_price_cents)}</span>
                <span className="animate-pop rounded-full bg-rose-600 px-2 py-0.5 text-xs font-bold text-white">
                  -{Math.round((1 - item.price_cents / item.original_price_cents) * 100)}%
                </span>
                {item.offer_label && (
                  <span className="rounded-full bg-amber-100 px-2 py-0.5 text-xs font-bold text-amber-800">
                    {item.offer_label}
                  </span>
                )}
              </div>
            ) : (
              <p className="mt-1 text-base font-semibold text-slate-700">{formatPrice(item.price_cents)}</p>
            )}
            {item.description && <p className="mt-2 text-sm text-slate-500">{item.description}</p>}
          </div>

          {groups.map((group) => {
            const error = evaluation.groupErrors[group.id];
            const required = isRequired(group);
            const selected = chosen[group.id] ?? [];
            const atMax = group.max_select !== null && selected.length >= group.max_select;
            const single = group.max_select === 1;

            return (
              <section
                key={group.id}
                ref={(el) => {
                  groupRefs.current[group.id] = el;
                }}
                className="mt-3 border-t-8 border-slate-100"
              >
                <div
                  key={showErrors && error ? `err-${shake}` : "ok"}
                  className={`flex items-start justify-between gap-3 px-5 py-3 transition-colors duration-300 ${
                    showErrors && error ? "animate-shake bg-red-50" : ""
                  }`}
                >
                  <div>
                    <h3 className="text-base font-bold text-slate-900">{group.name}</h3>
                    <p className={`text-xs ${showErrors && error ? "text-red-600" : "text-slate-500"}`}>
                      {showErrors && error ? error : groupRuleText(group, t)}
                    </p>
                  </div>
                  {group.kind === "choice" &&
                    (required ? (
                      error ? (
                        <span
                          className={`shrink-0 rounded-full px-2.5 py-1 text-xs font-semibold ${
                            showErrors ? "bg-red-600 text-white" : "bg-slate-900 text-white"
                          }`}
                        >
                          {t("Required")}
                        </span>
                      ) : (
                        <span className="shrink-0 animate-scale-in rounded-full bg-green-100 px-2.5 py-1 text-xs font-semibold text-green-700">
                          ✓ {t("Done")}
                        </span>
                      )
                    ) : (
                      <span className="shrink-0 rounded-full bg-slate-100 px-2.5 py-1 text-xs font-semibold text-slate-600">
                        {t("Optional")}
                      </span>
                    ))}
                </div>

                {group.kind === "choice" ? (
                  <ul className="divide-y divide-slate-100 px-5">
                    {group.menu_options.map((opt) => {
                      const on = selected.includes(opt.id);
                      const disabled = !on && atMax && !single;
                      return (
                        <li key={opt.id}>
                          <button
                            type="button"
                            onClick={() => toggleChoice(group, opt.id)}
                            disabled={disabled}
                            className="group/opt -mx-2 flex w-[calc(100%+1rem)] items-center gap-3 rounded-xl px-2 py-3 text-left hover:bg-slate-50 disabled:opacity-40 disabled:hover:bg-transparent"
                          >
                            <span
                              className={`flex h-5 w-5 shrink-0 items-center justify-center border-2 text-[11px] font-bold transition duration-200 ${
                                single ? "rounded-full" : "rounded-md"
                              } ${
                                on
                                  ? "scale-110 border-brand-600 bg-brand-600 text-white"
                                  : "border-slate-300 group-hover/opt:border-slate-400"
                              }`}
                            >
                              {on && (
                                <span className="animate-pop">
                                  {single ? <span className="block h-2 w-2 rounded-full bg-white" /> : "✓"}
                                </span>
                              )}
                            </span>
                            <span className={`flex-1 text-sm transition ${on ? "font-semibold text-slate-900" : "text-slate-700"}`}>{opt.name}</span>
                            {opt.price_cents > 0 && (
                              <span className="text-sm text-slate-500">+{formatPrice(opt.price_cents)}</span>
                            )}
                          </button>
                        </li>
                      );
                    })}
                  </ul>
                ) : (
                  <ul className="divide-y divide-slate-100 px-5">
                    {group.menu_options.map((opt) => {
                      const level = levels[opt.id] ?? "regular";
                      const choices: { value: Level; label: string }[] = [
                        { value: "remove", label: t("No") },
                        { value: "regular", label: t("Regular") },
                      ];
                      if (opt.allow_extra) {
                        choices.push({
                          value: "extra",
                          label:
                            opt.price_cents > 0
                              ? t("Extra +{price}", { price: formatPrice(opt.price_cents) })
                              : t("Extra"),
                        });
                      }
                      return (
                        <li key={opt.id} className="flex flex-wrap items-center justify-between gap-2 py-3">
                          <span
                            className={`text-sm transition-all duration-300 ${
                              level === "remove"
                                ? "text-slate-400 line-through"
                                : level === "extra"
                                ? "font-semibold text-brand-700"
                                : "text-slate-900"
                            }`}
                          >
                            {opt.name}
                          </span>
                          <div className="flex rounded-full bg-slate-100 p-0.5" role="radiogroup" aria-label={opt.name}>
                            {choices.map((c) => {
                              const active = level === c.value;
                              return (
                                <button
                                  key={c.value}
                                  type="button"
                                  role="radio"
                                  aria-checked={active}
                                  onClick={() => setLevels((prev) => ({ ...prev, [opt.id]: c.value }))}
                                  className={`rounded-full px-3 py-1 text-xs font-semibold transition ${
                                    active
                                      ? c.value === "remove"
                                        ? "bg-red-600 text-white shadow-sm"
                                        : c.value === "extra"
                                        ? "bg-brand-600 text-white shadow-sm"
                                        : "bg-white text-slate-900 shadow-sm"
                                      : "text-slate-500 hover:text-slate-800"
                                  }`}
                                >
                                  {c.label}
                                </button>
                              );
                            })}
                          </div>
                        </li>
                      );
                    })}
                  </ul>
                )}
              </section>
            );
          })}

          <section className="mt-3 border-t-8 border-slate-100 px-5 py-4">
            <h3 className="text-base font-bold text-slate-900">{t("Special instructions")}</h3>
            <textarea
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              rows={2}
              maxLength={200}
              placeholder={t("e.g. Sauce on the side, well toasted…")}
              className="mt-2 w-full resize-none rounded-xl border border-slate-300 px-3 py-2 text-sm"
            />
          </section>
        </div>

        {/* Sticky footer */}
        <div className="border-t border-slate-200 bg-white px-5 py-4">
          {summary.length > 0 && (
            <p className="mb-2 line-clamp-2 text-xs text-slate-500">{summary.join(" · ")}</p>
          )}
          <div className="flex items-center gap-3">
            <div className="flex items-center rounded-full bg-slate-100">
              <button
                type="button"
                onClick={() => setQuantity((q) => Math.max(1, q - 1))}
                className="h-10 w-10 rounded-full text-lg font-bold text-slate-700 hover:bg-slate-200 disabled:opacity-40"
                disabled={quantity <= 1}
                aria-label={t("Decrease quantity")}
              >
                −
              </button>
              <span key={quantity} className="w-6 animate-pop text-center text-sm font-semibold">{quantity}</span>
              <button
                type="button"
                onClick={() => setQuantity((q) => Math.min(99, q + 1))}
                className="h-10 w-10 rounded-full text-lg font-bold text-slate-700 hover:bg-slate-200"
                aria-label={t("Increase quantity")}
              >
                +
              </button>
            </div>
            <button
              type="button"
              onClick={handleAdd}
              disabled={!onAdd}
              className={`flex flex-1 items-center justify-between rounded-full px-5 py-3 text-sm font-semibold text-white ${
                hasErrors
                  ? "bg-slate-400"
                  : "bg-gradient-to-r from-brand-500 to-brand-600 shadow-glow hover:-translate-y-0.5 hover:brightness-110"
              } disabled:cursor-not-allowed`}
            >
              <span>{onAdd ? t("Add {n} to order", { n: quantity }) : t("Preview only")}</span>
              <span key={totalCents} className="inline-block animate-fade-in">
                {formatPrice(totalCents)}
              </span>
            </button>
          </div>
        </div>
      </div>
    </div>,
    document.body
  );
}
