import DashboardShell from "@/components/DashboardShell";
import { CartProvider } from "@/lib/cart-context";
import { createClient } from "@/lib/supabase/server";
import CompleteProfileForm from "./CompleteProfileForm";

const NAV_ITEMS = [
  { href: "/client", label: "Browse" },
  { href: "/client/cart", label: "Cart" },
  { href: "/client/orders", label: "My orders" },
  { href: "/client/settings", label: "Settings" },
];

export default async function ClientLayout({ children }: { children: React.ReactNode }) {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const [{ data: profile }, { count: addressCount }] = await Promise.all([
    supabase.from("profiles").select("phone").eq("id", user!.id).single(),
    supabase
      .from("client_addresses")
      .select("*", { count: "exact", head: true })
      .eq("client_id", user!.id),
  ]);

  const needsPhone = !profile?.phone;
  const needsAddress = !addressCount;

  if (needsPhone || needsAddress) {
    return (
      <CartProvider>
        <DashboardShell roleLabel="Client" navItems={NAV_ITEMS}>
          <CompleteProfileForm needsPhone={needsPhone} needsAddress={needsAddress} />
        </DashboardShell>
      </CartProvider>
    );
  }

  return (
    <CartProvider>
      <DashboardShell roleLabel="Client" navItems={NAV_ITEMS}>
        {children}
      </DashboardShell>
    </CartProvider>
  );
}
