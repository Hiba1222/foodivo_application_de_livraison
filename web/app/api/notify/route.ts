import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { sendOrderStatusEmails } from "@/lib/email";
import { sendPushToClient } from "@/lib/fcm";

// Called by the mobile app after it updates an order status directly in Supabase.
// Auth: Supabase JWT in Authorization header (the user's session token).
export async function POST(req: Request) {
  const authHeader = req.headers.get("authorization") ?? "";
  const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : null;
  if (!token) return Response.json({ error: "Unauthorized" }, { status: 401 });

  let body: { orderId?: string; newStatus?: string };
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: "Bad request" }, { status: 400 });
  }

  const { orderId, newStatus } = body;
  if (!orderId || !newStatus) return Response.json({ error: "Missing orderId or newStatus" }, { status: 400 });

  // Verify the JWT belongs to a real user
  const supabase = createClient();
  const { data: { user }, error: authError } = await supabase.auth.getUser(token);
  if (authError || !user) return Response.json({ error: "Unauthorized" }, { status: 401 });

  const admin = createAdminClient();

  // Fetch order context
  const { data: order, error: orderError } = await admin
    .from("orders")
    .select("id, total_cents, client_id, restaurant_id, driver_id, restaurants(name, owner_id), profiles!orders_client_id_fkey(full_name)")
    .eq("id", orderId)
    .single();

  if (orderError || !order) return Response.json({ error: "Order not found" }, { status: 404 });

  // Verify the caller is a party on this order (security check)
  const restaurant = order.restaurants as any;
  const isParty =
    user.id === order.client_id ||
    user.id === restaurant?.owner_id ||
    user.id === order.driver_id;
  if (!isParty) return Response.json({ error: "Forbidden" }, { status: 403 });

  // Fetch emails for client and restaurant owner
  const [clientEmailResult, restaurantEmailResult, driverNameResult] = await Promise.all([
    admin.auth.admin.getUserById(order.client_id),
    restaurant?.owner_id ? admin.auth.admin.getUserById(restaurant.owner_id) : Promise.resolve({ data: { user: null } }),
    order.driver_id ? admin.from("profiles").select("full_name").eq("id", order.driver_id).single() : Promise.resolve({ data: null }),
  ]);

  await sendOrderStatusEmails({
    orderId: order.id,
    status: newStatus,
    clientEmail: clientEmailResult.data.user?.email ?? null,
    clientName: (order.profiles as any)?.full_name ?? null,
    restaurantEmail: restaurantEmailResult.data.user?.email ?? null,
    restaurantName: restaurant?.name ?? null,
    driverName: (driverNameResult.data as any)?.full_name ?? null,
    totalCents: order.total_cents,
  });

  sendPushToClient(order.client_id, newStatus);

  return Response.json({ ok: true });
}
