import nodemailer from "nodemailer";

function createTransport() {
  return nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: Number(process.env.SMTP_PORT ?? 587),
    secure: process.env.SMTP_SECURE === "true",
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
    },
  });
}

type AccountType = "restaurant" | "driver";
type ApprovalAction = "approved" | "disapproved" | "suspended";

const appName = "Foodivo";

function buildHtml(heading: string, body: string, extra = "") {
  return `<!DOCTYPE html><html><body style="font-family:sans-serif;max-width:560px;margin:40px auto;color:#1e293b">
<h2 style="margin-bottom:8px">${heading}</h2>
<p style="color:#475569;line-height:1.6">${body}</p>
${extra}
<p style="margin-top:32px;color:#94a3b8;font-size:13px">— The ${appName} team</p>
</body></html>`;
}

function buildEmail(
  type: AccountType,
  action: ApprovalAction,
  name: string | null
): { subject: string; html: string } {
  const entity = type === "restaurant" ? "restaurant" : "driver";
  const display = name ?? `your ${entity} account`;

  if (action === "approved") {
    return {
      subject: `Your ${entity} account has been approved — ${appName}`,
      html: buildHtml(
        `🎉 You're approved!`,
        `Great news — <strong>${display}</strong> has been approved on ${appName}. ` +
          (type === "restaurant"
            ? "You can now publish your menu, set your hours, and start receiving orders."
            : "You can now go online and start accepting deliveries.")
      ),
    };
  }

  if (action === "disapproved") {
    return {
      subject: `Your ${entity} account application — ${appName}`,
      html: buildHtml(
        `Account application update`,
        `After review, we were unable to approve <strong>${display}</strong> at this time. ` +
          `If you believe this is a mistake or would like more information, please contact our support team.`
      ),
    };
  }

  // suspended
  return {
    subject: `Your ${entity} account has been suspended — ${appName}`,
    html: buildHtml(
      `Account suspended`,
      `Your ${entity} account (<strong>${display}</strong>) has been suspended by an administrator. ` +
        `Please contact support if you have any questions.`
    ),
  };
}

export async function sendApprovalEmail(
  to: string,
  type: AccountType,
  action: ApprovalAction,
  name: string | null
) {
  if (!process.env.SMTP_HOST || !process.env.SMTP_USER) return;

  const { subject, html } = buildEmail(type, action, name);
  const from = process.env.SMTP_FROM ?? process.env.SMTP_USER;

  try {
    await createTransport().sendMail({ from, to, subject, html });
  } catch (err) {
    console.error("[email] failed to send approval email:", err);
  }
}

// ─── Order status notifications ───────────────────────────────────────────────

export interface OrderEmailContext {
  orderId: string;
  status: string;
  clientEmail: string | null;
  clientName: string | null;
  restaurantEmail: string | null;
  restaurantName: string | null;
  driverName: string | null;
  totalCents: number;
}

function formatTotal(cents: number) {
  return `${(cents / 1000).toFixed(3)} TND`;
}

function orderTag(orderId: string) {
  return orderId.slice(0, 8).toUpperCase();
}

function pill(text: string, color: string) {
  return `<span style="display:inline-block;padding:4px 12px;border-radius:999px;background:${color};color:#fff;font-weight:700;font-size:14px">${text}</span>`;
}

type EmailSpec = { subject: string; html: string } | null;

function clientEmail(ctx: OrderEmailContext): EmailSpec {
  const tag = orderTag(ctx.orderId);
  const total = formatTotal(ctx.totalCents);
  const name = ctx.clientName ? `Hi ${ctx.clientName},` : "Hello,";
  const rest = ctx.restaurantName ?? "the restaurant";

  switch (ctx.status) {
    case "pending":
      return {
        subject: `Order #${tag} received — ${appName}`,
        html: buildHtml(
          `🛒 Order received!`,
          `${name} Your order at <strong>${rest}</strong> has been received and is waiting for confirmation.<br><br>Total: <strong>${total}</strong>`
        ),
      };
    case "accepted":
      return {
        subject: `Order #${tag} accepted — ${appName}`,
        html: buildHtml(
          `✅ Order accepted`,
          `${name} Great news — <strong>${rest}</strong> has accepted your order and is now preparing it. We'll notify you when it's ready for pickup.`
        ),
      };
    case "rejected":
      return {
        subject: `Order #${tag} could not be processed — ${appName}`,
        html: buildHtml(
          `Order not accepted`,
          `${name} Unfortunately <strong>${rest}</strong> was unable to accept your order at this time. You have not been charged. Feel free to try again or choose another restaurant.`
        ),
      };
    case "driver_assigned":
      return {
        subject: `Order #${tag} — driver on the way — ${appName}`,
        html: buildHtml(
          `🛵 Driver assigned`,
          `${name} A driver${ctx.driverName ? ` (<strong>${ctx.driverName}</strong>)` : ""} has been assigned and is heading to ${rest} to pick up your order.`
        ),
      };
    case "picked_up":
      return {
        subject: `Order #${tag} is on its way! — ${appName}`,
        html: buildHtml(
          `🚀 Your order is on the way!`,
          `${name} Your order from <strong>${rest}</strong> has been picked up and is now on its way to you. Get ready!`
        ),
      };
    case "delivered":
      return {
        subject: `Order #${tag} delivered — ${appName}`,
        html: buildHtml(
          `🎉 Order delivered!`,
          `${name} Your order from <strong>${rest}</strong> has been delivered. Enjoy your meal! Total paid: <strong>${total}</strong>.`
        ),
      };
    case "cancelled":
      return {
        subject: `Order #${tag} cancelled — ${appName}`,
        html: buildHtml(
          `Order cancelled`,
          `${name} Your order at <strong>${rest}</strong> has been cancelled. You have not been charged.`
        ),
      };
    default:
      return null;
  }
}

function restaurantEmail(ctx: OrderEmailContext): EmailSpec {
  const tag = orderTag(ctx.orderId);
  const total = formatTotal(ctx.totalCents);

  switch (ctx.status) {
    case "pending":
      return {
        subject: `🔔 New order #${tag} — ${appName}`,
        html: buildHtml(
          `New order incoming!`,
          `You have a new order on ${appName}.<br><br>Order <strong>#${tag}</strong> — Total: <strong>${total}</strong><br><br>Open the app to review and accept it.`,
          pill("New order", "#f59e0b")
        ),
      };
    case "driver_assigned":
      return {
        subject: `Driver coming for order #${tag} — ${appName}`,
        html: buildHtml(
          `🛵 Driver on the way`,
          `A driver${ctx.driverName ? ` (<strong>${ctx.driverName}</strong>)` : ""} has been assigned to order <strong>#${tag}</strong> and is heading to your location for pickup. Please have the order ready.`
        ),
      };
    case "delivered":
      return {
        subject: `Order #${tag} delivered — ${appName}`,
        html: buildHtml(
          `✅ Order delivered`,
          `Order <strong>#${tag}</strong> (${total}) has been successfully delivered to the client.`
        ),
      };
    default:
      return null;
  }
}

async function send(to: string | null, spec: EmailSpec) {
  if (!to || !spec || !process.env.SMTP_HOST || !process.env.SMTP_USER) return;
  const from = process.env.SMTP_FROM ?? process.env.SMTP_USER;
  try {
    await createTransport().sendMail({ from, to, subject: spec.subject, html: spec.html });
  } catch (err) {
    console.error(`[email] failed to send "${spec.subject}" to ${to}:`, err);
  }
}

export async function sendRawEmail(to: string, subject: string, html: string) {
  if (!process.env.SMTP_HOST || !process.env.SMTP_USER) return;
  const from = process.env.SMTP_FROM ?? process.env.SMTP_USER;
  try {
    await createTransport().sendMail({ from, to, subject, html });
  } catch (err) {
    console.error(`[email] failed to send "${subject}" to ${to}:`, err);
    throw err;
  }
}

export async function sendOrderStatusEmails(ctx: OrderEmailContext) {
  await Promise.all([
    send(ctx.clientEmail, clientEmail(ctx)),
    send(ctx.restaurantEmail, restaurantEmail(ctx)),
  ]);
}

// ─── Invoice / report emails ───────────────────────────────────────────────────

function fmtPrice(cents: number) {
  return `${(cents / 1000).toFixed(3)} TND`;
}

function fmtDate(iso: string | null) {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString("en-GB", { year: "numeric", month: "short", day: "numeric" });
}

function periodLabel(p: string) {
  return p === "all" ? "All time" : `Last ${p} days`;
}

export async function sendInvoiceEmail(
  to: string,
  order: {
    id: string;
    created_at: string;
    subtotal_cents: number;
    delivery_fee_cents: number;
    total_cents: number;
    status: string;
    client_name: string | null;
    restaurant_name: string | null;
    delivery_address: string | null;
    items: { name: string; quantity: number; unit_price_cents: number }[];
  }
) {
  const tag = order.id.slice(0, 8).toUpperCase();
  const rows = order.items
    .map(
      (i) =>
        `<tr><td style="padding:6px 0;border-bottom:1px solid #e2e8f0">${i.name}</td>
         <td style="padding:6px 0;border-bottom:1px solid #e2e8f0;text-align:center">${i.quantity}</td>
         <td style="padding:6px 0;border-bottom:1px solid #e2e8f0;text-align:right">${fmtPrice(i.unit_price_cents)}</td>
         <td style="padding:6px 0;border-bottom:1px solid #e2e8f0;text-align:right;font-weight:600">${fmtPrice(i.unit_price_cents * i.quantity)}</td></tr>`
    )
    .join("");

  const html = `<!DOCTYPE html><html><body style="font-family:sans-serif;max-width:600px;margin:40px auto;color:#1e293b">
<h2 style="margin-bottom:4px;color:#e85d04">Foodivo</h2>
<p style="color:#64748b;margin-top:0">Invoice · Order #${tag}</p>
<table style="width:100%;border-collapse:collapse;margin-bottom:16px">
  <tr style="border-bottom:2px solid #e2e8f0;color:#94a3b8;font-size:12px">
    <th style="padding:4px 0;text-align:left">Item</th>
    <th style="padding:4px 0;text-align:center">Qty</th>
    <th style="padding:4px 0;text-align:right">Unit price</th>
    <th style="padding:4px 0;text-align:right">Total</th>
  </tr>
  ${rows}
  <tr><td colspan="3" style="padding:8px 0;text-align:right;color:#64748b">Subtotal</td><td style="padding:8px 0;text-align:right">${fmtPrice(order.subtotal_cents)}</td></tr>
  <tr><td colspan="3" style="padding:4px 0;text-align:right;color:#64748b">Delivery fee</td><td style="padding:4px 0;text-align:right">${fmtPrice(order.delivery_fee_cents)}</td></tr>
  <tr style="font-weight:700;font-size:16px"><td colspan="3" style="padding:8px 0;text-align:right">Total</td><td style="padding:8px 0;text-align:right;color:#e85d04">${fmtPrice(order.total_cents)}</td></tr>
</table>
<p style="font-size:13px;color:#64748b">
  <strong>Restaurant:</strong> ${order.restaurant_name ?? "—"}<br>
  <strong>Delivered to:</strong> ${order.delivery_address ?? "—"}<br>
  <strong>Date:</strong> ${fmtDate(order.created_at)}
</p>
<p style="margin-top:32px;color:#94a3b8;font-size:13px">— The Foodivo team</p>
</body></html>`;

  if (!process.env.SMTP_HOST || !process.env.SMTP_USER) return;
  const from = process.env.SMTP_FROM ?? process.env.SMTP_USER;
  try {
    await createTransport().sendMail({
      from,
      to,
      subject: `Invoice for order #${tag} — Foodivo`,
      html,
    });
  } catch (err) {
    console.error("[email] failed to send invoice:", err);
    throw err;
  }
}

export async function sendRestaurantReportEmail(
  to: string,
  data: {
    restaurantName: string;
    period: string;
    orders: { id: string; subtotal_cents: number; delivered_at: string | null; fee: number; net: number; profiles?: { full_name?: string } | null }[];
  }
) {
  const { restaurantName, period, orders } = data;
  const totals = orders.reduce(
    (a, o) => ({ gross: a.gross + o.subtotal_cents, fee: a.fee + o.fee, net: a.net + o.net }),
    { gross: 0, fee: 0, net: 0 }
  );

  const rows = orders
    .map(
      (o) =>
        `<tr>
          <td style="padding:5px 0;border-bottom:1px solid #e2e8f0">${fmtDate(o.delivered_at)}</td>
          <td style="padding:5px 0;border-bottom:1px solid #e2e8f0">${(o.profiles as any)?.full_name ?? "—"}</td>
          <td style="padding:5px 0;border-bottom:1px solid #e2e8f0;text-align:right">${fmtPrice(o.subtotal_cents)}</td>
          <td style="padding:5px 0;border-bottom:1px solid #e2e8f0;text-align:right;color:#ef4444">−${fmtPrice(o.fee)}</td>
          <td style="padding:5px 0;border-bottom:1px solid #e2e8f0;text-align:right;font-weight:600;color:#e85d04">${fmtPrice(o.net)}</td>
        </tr>`
    )
    .join("");

  const html = `<!DOCTYPE html><html><body style="font-family:sans-serif;max-width:650px;margin:40px auto;color:#1e293b">
<h2 style="margin-bottom:4px;color:#e85d04">Foodivo</h2>
<p style="color:#64748b;margin-top:0">Payout report · ${restaurantName} · ${periodLabel(period)}</p>
<div style="display:flex;gap:16px;margin-bottom:24px">
  <div style="background:#fff7ed;border-radius:12px;padding:16px 24px;flex:1">
    <p style="margin:0;font-size:12px;color:#ea580c">Net payout</p>
    <p style="margin:4px 0 0;font-size:22px;font-weight:700;color:#9a3412">${fmtPrice(totals.net)}</p>
  </div>
  <div style="background:#f8fafc;border-radius:12px;padding:16px 24px;flex:1">
    <p style="margin:0;font-size:12px;color:#64748b">Gross revenue</p>
    <p style="margin:4px 0 0;font-size:18px;font-weight:700">${fmtPrice(totals.gross)}</p>
  </div>
  <div style="background:#f8fafc;border-radius:12px;padding:16px 24px;flex:1">
    <p style="margin:0;font-size:12px;color:#64748b">Platform fees</p>
    <p style="margin:4px 0 0;font-size:18px;font-weight:700">${fmtPrice(totals.fee)}</p>
  </div>
</div>
<table style="width:100%;border-collapse:collapse;font-size:13px">
  <tr style="border-bottom:2px solid #e2e8f0;color:#94a3b8;font-size:11px;text-transform:uppercase;letter-spacing:.05em">
    <th style="padding:4px 0;text-align:left">Date</th>
    <th style="padding:4px 0;text-align:left">Client</th>
    <th style="padding:4px 0;text-align:right">Subtotal</th>
    <th style="padding:4px 0;text-align:right">Platform fee</th>
    <th style="padding:4px 0;text-align:right">Your payout</th>
  </tr>
  ${rows}
  <tr style="font-weight:700">
    <td colspan="2" style="padding:8px 0">Total (${orders.length} orders)</td>
    <td style="padding:8px 0;text-align:right">${fmtPrice(totals.gross)}</td>
    <td style="padding:8px 0;text-align:right;color:#ef4444">−${fmtPrice(totals.fee)}</td>
    <td style="padding:8px 0;text-align:right;color:#e85d04">${fmtPrice(totals.net)}</td>
  </tr>
</table>
<p style="margin-top:32px;color:#94a3b8;font-size:13px">— The Foodivo team</p>
</body></html>`;

  if (!process.env.SMTP_HOST || !process.env.SMTP_USER) return;
  const from = process.env.SMTP_FROM ?? process.env.SMTP_USER;
  try {
    await createTransport().sendMail({
      from,
      to,
      subject: `Payout report · ${restaurantName} · ${periodLabel(period)} — Foodivo`,
      html,
    });
  } catch (err) {
    console.error("[email] failed to send restaurant report:", err);
    throw err;
  }
}

export async function sendDriverReportEmail(
  to: string,
  data: {
    driverName: string;
    period: string;
    orders: { id: string; delivery_fee_cents: number; delivered_at: string | null; cut: number; net: number; restaurants?: { name?: string } | null }[];
  }
) {
  const { driverName, period, orders } = data;
  const totals = orders.reduce(
    (a, o) => ({ gross: a.gross + o.delivery_fee_cents, cut: a.cut + o.cut, net: a.net + o.net }),
    { gross: 0, cut: 0, net: 0 }
  );

  const rows = orders
    .map(
      (o) =>
        `<tr>
          <td style="padding:5px 0;border-bottom:1px solid #e2e8f0">${fmtDate(o.delivered_at)}</td>
          <td style="padding:5px 0;border-bottom:1px solid #e2e8f0">${(o.restaurants as any)?.name ?? "—"}</td>
          <td style="padding:5px 0;border-bottom:1px solid #e2e8f0;text-align:right">${fmtPrice(o.delivery_fee_cents)}</td>
          <td style="padding:5px 0;border-bottom:1px solid #e2e8f0;text-align:right;color:#ef4444">−${fmtPrice(o.cut)}</td>
          <td style="padding:5px 0;border-bottom:1px solid #e2e8f0;text-align:right;font-weight:600;color:#e85d04">${fmtPrice(o.net)}</td>
        </tr>`
    )
    .join("");

  const html = `<!DOCTYPE html><html><body style="font-family:sans-serif;max-width:650px;margin:40px auto;color:#1e293b">
<h2 style="margin-bottom:4px;color:#e85d04">Foodivo</h2>
<p style="color:#64748b;margin-top:0">Earnings report · ${driverName} · ${periodLabel(period)}</p>
<div style="display:flex;gap:16px;margin-bottom:24px">
  <div style="background:#fff7ed;border-radius:12px;padding:16px 24px;flex:1">
    <p style="margin:0;font-size:12px;color:#ea580c">Net earnings</p>
    <p style="margin:4px 0 0;font-size:22px;font-weight:700;color:#9a3412">${fmtPrice(totals.net)}</p>
  </div>
  <div style="background:#f8fafc;border-radius:12px;padding:16px 24px;flex:1">
    <p style="margin:0;font-size:12px;color:#64748b">Total delivery fees</p>
    <p style="margin:4px 0 0;font-size:18px;font-weight:700">${fmtPrice(totals.gross)}</p>
  </div>
  <div style="background:#f8fafc;border-radius:12px;padding:16px 24px;flex:1">
    <p style="margin:0;font-size:12px;color:#64748b">Platform fees</p>
    <p style="margin:4px 0 0;font-size:18px;font-weight:700">${fmtPrice(totals.cut)}</p>
  </div>
</div>
<table style="width:100%;border-collapse:collapse;font-size:13px">
  <tr style="border-bottom:2px solid #e2e8f0;color:#94a3b8;font-size:11px;text-transform:uppercase;letter-spacing:.05em">
    <th style="padding:4px 0;text-align:left">Date</th>
    <th style="padding:4px 0;text-align:left">Restaurant</th>
    <th style="padding:4px 0;text-align:right">Delivery fee</th>
    <th style="padding:4px 0;text-align:right">Platform cut</th>
    <th style="padding:4px 0;text-align:right">You earned</th>
  </tr>
  ${rows}
  <tr style="font-weight:700">
    <td colspan="2" style="padding:8px 0">Total (${orders.length} deliveries)</td>
    <td style="padding:8px 0;text-align:right">${fmtPrice(totals.gross)}</td>
    <td style="padding:8px 0;text-align:right;color:#ef4444">−${fmtPrice(totals.cut)}</td>
    <td style="padding:8px 0;text-align:right;color:#e85d04">${fmtPrice(totals.net)}</td>
  </tr>
</table>
<p style="margin-top:32px;color:#94a3b8;font-size:13px">— The Foodivo team</p>
</body></html>`;

  if (!process.env.SMTP_HOST || !process.env.SMTP_USER) return;
  const from = process.env.SMTP_FROM ?? process.env.SMTP_USER;
  try {
    await createTransport().sendMail({
      from,
      to,
      subject: `Earnings report · ${driverName} · ${periodLabel(period)} — Foodivo`,
      html,
    });
  } catch (err) {
    console.error("[email] failed to send driver report:", err);
    throw err;
  }
}
