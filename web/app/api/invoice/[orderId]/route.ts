import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { ORDER_ITEMS_SELECT } from "@/lib/order-items";
import { sendInvoiceEmail } from "@/lib/email";

export async function POST(req: Request, { params }: { params: { orderId: string } }) {
  const authHeader = req.headers.get("authorization") ?? "";
  const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : null;
  if (!token) return Response.json({ error: "Unauthorized" }, { status: 401 });

  const supabase = createClient();
  const { data: { user }, error: authError } = await supabase.auth.getUser(token);
  if (authError || !user) return Response.json({ error: "Unauthorized" }, { status: 401 });

  const admin = createAdminClient();

  const { data: order, error } = await admin
    .from("orders")
    .select(
      `id, status, subtotal_cents, delivery_fee_cents, total_cents,
       created_at, delivered_at, payment_method, payment_status, notes,
       client_id,
       restaurants(name, address),
       profiles!orders_client_id_fkey(full_name),
       client_addresses(address_line),
       ${ORDER_ITEMS_SELECT}`
    )
    .eq("id", params.orderId)
    .eq("client_id", user.id)
    .single();

  if (error || !order) return Response.json({ error: "Order not found" }, { status: 404 });
  if (order.status !== "delivered") return Response.json({ error: "Invoice only available for delivered orders" }, { status: 400 });

  const { data: authUser } = await admin.auth.admin.getUserById(user.id);
  const email = authUser.user?.email;
  if (!email) return Response.json({ error: "No email" }, { status: 400 });

  await sendInvoiceEmail(email, order as any);
  return Response.json({ ok: true });
}
