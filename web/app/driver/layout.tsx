import DashboardShell from "@/components/DashboardShell";
import { getMyDriverProfile } from "@/lib/driver";
import CreateDriverProfileForm from "./CreateDriverProfileForm";
import LocationTracker from "./LocationTracker";
import { getT } from "@/lib/i18n/server";
import AuthBackdrop from "@/components/AuthBackdrop";

const NAV_ITEMS = [
  { href: "/driver", label: "Overview" },
  { href: "/driver/available", label: "Available deliveries" },
  { href: "/driver/my-deliveries", label: "My deliveries" },
  { href: "/driver/history", label: "History" },
  { href: "/driver/settings", label: "Settings" },
];

export default async function DriverLayout({ children }: { children: React.ReactNode }) {
  const t = getT();
  const driver = await getMyDriverProfile();

  if (!driver) {
    return (
      <AuthBackdrop>
        <CreateDriverProfileForm />
      </AuthBackdrop>
    );
  }

  return (
    <DashboardShell roleLabel="Driver" navItems={NAV_ITEMS}>
      <LocationTracker enabled={driver.is_online} />
      {!driver.is_approved && (
        <div className="mb-6 rounded-xl bg-amber-50 px-4 py-3 text-sm text-amber-800 ring-1 ring-amber-200">
          {t("Your driver account is awaiting admin approval. You can't go online or accept deliveries until then.")}
        </div>
      )}
      {children}
    </DashboardShell>
  );
}
