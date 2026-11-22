/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./app/**/*.{js,ts,jsx,tsx}", "./components/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      colors: {
        brand: {
          50: "#fff7ed",
          100: "#ffedd5",
          200: "#fed7aa",
          300: "#fdba74",
          400: "#fb923c",
          500: "#f97316",
          600: "#ea580c",
          700: "#c2410c",
        },
      },
      boxShadow: {
        soft: "0 1px 2px rgb(15 23 42 / 0.04), 0 4px 16px -4px rgb(15 23 42 / 0.08)",
        lift: "0 2px 4px rgb(15 23 42 / 0.04), 0 16px 32px -8px rgb(15 23 42 / 0.18)",
        glow: "0 8px 24px -6px rgb(234 88 12 / 0.55)",
      },
      keyframes: {
        "fade-up": {
          from: { opacity: "0", transform: "translateY(12px)" },
          to: { opacity: "1", transform: "translateY(0)" },
        },
        "fade-in": { from: { opacity: "0" }, to: { opacity: "1" } },
        "scale-in": {
          from: { opacity: "0", transform: "scale(0.95)" },
          to: { opacity: "1", transform: "scale(1)" },
        },
        "sheet-up": {
          from: { opacity: "0.6", transform: "translateY(40px)" },
          to: { opacity: "1", transform: "translateY(0)" },
        },
        pop: {
          "0%": { transform: "scale(1)" },
          "40%": { transform: "scale(1.35)" },
          "100%": { transform: "scale(1)" },
        },
        wiggle: {
          "0%,100%": { transform: "rotate(0deg)" },
          "25%": { transform: "rotate(-12deg)" },
          "75%": { transform: "rotate(12deg)" },
        },
        shake: {
          "0%,100%": { transform: "translateX(0)" },
          "20%,60%": { transform: "translateX(-6px)" },
          "40%,80%": { transform: "translateX(6px)" },
        },
        float: {
          "0%,100%": { transform: "translate(0,0) scale(1)" },
          "50%": { transform: "translate(20px,-24px) scale(1.06)" },
        },
        shimmer: { from: { backgroundPosition: "-200% 0" }, to: { backgroundPosition: "200% 0" } },
        "toast-in": {
          from: { opacity: "0", transform: "translate(-50%, 16px) scale(0.96)" },
          to: { opacity: "1", transform: "translate(-50%, 0) scale(1)" },
        },
      },
      animation: {
        "fade-up": "fade-up 0.5s cubic-bezier(0.22,1,0.36,1) both",
        // "backwards" (not "both"): leaves no transform behind, so position:fixed children keep working.
        page: "fade-up 0.45s cubic-bezier(0.22,1,0.36,1) backwards",
        "fade-in": "fade-in 0.3s ease-out both",
        "scale-in": "scale-in 0.35s cubic-bezier(0.22,1,0.36,1) both",
        "sheet-up": "sheet-up 0.4s cubic-bezier(0.22,1,0.36,1) both",
        pop: "pop 0.45s cubic-bezier(0.34,1.56,0.64,1)",
        wiggle: "wiggle 0.5s ease-in-out",
        shake: "shake 0.45s ease-in-out",
        float: "float 12s ease-in-out infinite",
        "float-slow": "float 18s ease-in-out infinite reverse",
        shimmer: "shimmer 2.2s linear infinite",
        "toast-in": "toast-in 0.35s cubic-bezier(0.22,1,0.36,1) both",
      },
    },
  },
  plugins: [],
};
