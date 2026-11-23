import { createSign } from "crypto";
import { createAdminClient } from "@/lib/supabase/admin";

const PROJECT_ID = process.env.FCM_PROJECT_ID ?? "";
const CLIENT_EMAIL = process.env.FCM_CLIENT_EMAIL ?? "";
const PRIVATE_KEY = (process.env.FCM_PRIVATE_KEY ?? "").replace(/\\n/g, "\n");

function makeJwt(): string {
  const now = Math.floor(Date.now() / 1000);
  const header = Buffer.from(JSON.stringify({ alg: "RS256", typ: "JWT" })).toString("base64url");
  const payload = Buffer.from(
    JSON.stringify({
      iss: CLIENT_EMAIL,
      sub: CLIENT_EMAIL,
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
    })
  ).toString("base64url");

  const sign = createSign("RSA-SHA256");
  sign.update(`${header}.${payload}`);
  const sig = sign.sign(PRIVATE_KEY, "base64url");
  return `${header}.${payload}.${sig}`;
}

let _cached: { token: string; expiresAt: number } | null = null;

async function getAccessToken(): Promise<string> {
  const now = Date.now();
  if (_cached && now < _cached.expiresAt) return _cached.token;

  const jwt = makeJwt();
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) throw new Error(`OAuth2 token exchange failed: ${await res.text()}`);
  const json = await res.json();
  _cached = { token: json.access_token, expiresAt: now + (json.expires_in - 60) * 1000 };
  return _cached.token;
}

const STATUS_MESSAGES: Record<string, { title: string; body: string }> = {
  accepted: { title: "Order accepted", body: "The restaurant has accepted your order." },
  rejected: { title: "Order rejected", body: "The restaurant could not accept your order." },
  ready_for_pickup: { title: "Order ready", body: "Your order is ready and waiting for a driver." },
  driver_assigned: { title: "Driver assigned", body: "A driver has been assigned to your order." },
  picked_up: { title: "Order on the way", body: "Your order has been picked up and is on the way!" },
  delivered: { title: "Order delivered", body: "Your order has been delivered. Enjoy your meal!" },
  cancelled: { title: "Order cancelled", body: "Your order has been cancelled." },
};

export async function sendPushToClient(
  clientId: string,
  status: string
): Promise<void> {
  if (!PROJECT_ID || !CLIENT_EMAIL || !PRIVATE_KEY || !PRIVATE_KEY.includes("PRIVATE KEY")) {
    console.error("[FCM] Missing credentials — check FCM_* env vars");
    return;
  }
  const msg = STATUS_MESSAGES[status];
  if (!msg) return;

  void (async () => {
    try {
      // Use admin client so RLS doesn't block reading another user's tokens
      const admin = createAdminClient();
      const { data: rows, error: tokenErr } = await admin
        .from("fcm_tokens")
        .select("token")
        .eq("user_id", clientId);

      if (tokenErr) { console.error("[FCM] Token lookup failed:", tokenErr.message); return; }

      const tokens: string[] = (rows ?? []).map((r: { token: string }) => r.token);
      console.log(`[FCM] Sending "${status}" push to ${tokens.length} token(s) for client ${clientId}`);
      if (!tokens.length) return;

      const accessToken = await getAccessToken();
      const results = await Promise.all(
        tokens.map((token) =>
          fetch(`https://fcm.googleapis.com/v1/projects/${PROJECT_ID}/messages:send`, {
            method: "POST",
            headers: {
              Authorization: `Bearer ${accessToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              message: {
                token,
                notification: msg,
                android: { priority: "HIGH" },
              },
            }),
          }).then(async (r) => {
            if (!r.ok) console.error("[FCM] Send failed:", await r.text());
            return r.ok;
          })
        )
      );
      console.log(`[FCM] Results: ${results.filter(Boolean).length}/${results.length} sent`);
    } catch (e) {
      console.error("[FCM] Unexpected error:", e);
    }
  })();
}
