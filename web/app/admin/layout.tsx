import DashboardShell from "@/components/DashboardShell";

const NAV_ITEMS = [
  { href: "/admin", label: "Overview" },
  { href: "/admin/restaurants", label: "Restaurants" },
  { href: "/admin/drivers", label: "Drivers" },
  { href: "/admin/orders", label: "Orders" },
  { href: "/admin/users", label: "Users" },
  { href: "/admin/fees", label: "Fees" },
];

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return (
    <DashboardShell roleLabel="Admin" navItems={NAV_ITEMS}>
      {children}
    </DashboardShell>
  );
}
