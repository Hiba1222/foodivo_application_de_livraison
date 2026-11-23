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
