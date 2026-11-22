/* eslint-disable @next/next/no-img-element */

/**
 * Foodivo wordmark (public/foodivo-logo.png, 471×231).
 * `mix-blend-multiply` makes the image's white background vanish on tinted/blurred surfaces.
 */
export default function Logo({ className = "h-10" }: { className?: string }) {
  return (
    <img
      src="/foodivo-logo.png"
      alt="Foodivo"
      width={471}
      height={231}
      draggable={false}
      className={`w-auto select-none mix-blend-multiply ${className}`}
    />
  );
}
