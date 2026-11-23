"use server";

import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { ORDER_ITEMS_SELECT } from "@/lib/order-items";
import { sendInvoiceEmail } from "@/lib/email";
import { redirect } from "next/navigation";

export async function emailInvoice(orderId: string) {
  const supabase = createClient();
  const admin = createAdminClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const { data: order } = await supabase
    .from("orders")
    .select(
      `id, status, subtotal_cents, delivery_fee_cents, total_cents,
       created_at, delivered_at, payment_method, payment_status, notes,
       restaurants(name, address),
       profiles!orders_client_id_fkey(full_name),
       client_addresses(address_line),
       ${ORDER_ITEMS_SELECT}`
    )
    .eq("id", orderId)
    .eq("client_id", user.id)
    .single();

  if (!order) return;

  const { data: authUser } = await admin.auth.admin.getUserById(user.id);
  const email = authUser.user?.email;
  if (!email) return;

  await sendInvoiceEmail(email, order);
}
