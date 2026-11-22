import LanguageSwitcher from "./LanguageSwitcher";

/** Animated full-screen background for login / signup / onboarding screens (with language picker top-right). */
export default function AuthBackdrop({ children }: { children: React.ReactNode }) {
  return (
    <div className="relative flex min-h-screen items-center justify-center overflow-hidden bg-gradient-to-br from-brand-50 via-white to-rose-50 px-4 py-10">
      <div className="pointer-events-none absolute -left-24 -top-24 h-96 w-96 animate-float rounded-full bg-brand-300/40 blur-3xl" />
      <div className="pointer-events-none absolute -bottom-32 -right-24 h-[28rem] w-[28rem] animate-float-slow rounded-full bg-rose-300/40 blur-3xl" />
      <div className="pointer-events-none absolute left-1/2 top-1/3 h-64 w-64 animate-float-slow rounded-full bg-yellow-200/40 blur-3xl" />
      <div className="pointer-events-none absolute inset-0 select-none text-4xl opacity-20" aria-hidden="true">
        <span className="absolute left-[10%] top-[18%] animate-float">🍕</span>
        <span className="absolute right-[12%] top-[14%] animate-float-slow">🍔</span>
        <span className="absolute bottom-[16%] left-[14%] animate-float-slow">🌮</span>
        <span className="absolute bottom-[20%] right-[10%] animate-float">🥗</span>
      </div>
      <div className="absolute right-4 top-4 z-20 sm:right-6 sm:top-6">
        <LanguageSwitcher glass />
      </div>
      <div className="relative w-full animate-scale-in">{children}</div>
    </div>
  );
}
