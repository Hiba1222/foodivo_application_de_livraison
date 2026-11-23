import DashboardShell from "@/components/DashboardShell";
import { getMyRestaurant } from "@/lib/restaurant";
import CreateRestaurantForm from "./CreateRestaurantForm";
import { getT } from "@/lib/i18n/server";
import AuthBackdrop from "@/components/AuthBackdrop";

const NAV_ITEMS = [
  { href: "/restaurant", label: "Overview" },
  { href: "/restaurant/menu", label: "Menu" },
  { href: "/restaurant/orders", label: "Orders" },
  { href: "/restaurant/analytics", label: "Analytics" },
  { href: "/restaurant/settings", label: "Settings" },
];

export default async function RestaurantLayout({ children }: { children: React.ReactNode }) {
  const t = getT();
  const restaurant = await getMyRestaurant();

  // Owner hasn't created their restaurant profile yet — show onboarding
  // instead of the dashboard shell (no menu/orders to show yet anyway).
  if (!restaurant) {
    return (
      <AuthBackdrop>
        <CreateRestaurantForm />
      </AuthBackdrop>
    );
  }

  return (
    <DashboardShell roleLabel="Restaurant" navItems={NAV_ITEMS}>
      {!restaurant.is_approved && (
        <div className="mb-6 rounded-xl bg-amber-50 px-4 py-3 text-sm text-amber-800 ring-1 ring-amber-200">
          {t("Your restaurant is awaiting admin approval. It won't appear to clients until approved.")}
        </div>
      )}
      {children}
    </DashboardShell>
  );
}
