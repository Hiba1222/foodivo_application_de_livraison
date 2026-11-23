import { createAdminClient } from "@/lib/supabase/admin";
import { sendRawEmail } from "@/lib/email";

export async function POST(req: Request) {
  const { email } = await req.json().catch(() => ({}));
  if (!email || typeof email !== "string") {
    return Response.json({ error: "Email required" }, { status: 400 });
  }

  const supabase = createAdminClient();

  const { data, error } = await supabase.auth.admin.generateLink({
    type: "recovery",
    email: email.trim(),
  });

  if (error) {
    console.error("[forgot-password] generateLink error:", error);
    // Don't reveal whether the email exists
    return Response.json({ ok: true });
  }

  // Use the email_otp (6-digit code) — no redirect URL needed, no link expiry issues.
  const code = data.properties.email_otp;

  const html = `<!DOCTYPE html><html><body style="font-family:sans-serif;max-width:560px;margin:40px auto;color:#1e293b">
<h2 style="margin-bottom:8px">🔐 Reset your Foodivo password</h2>
<p style="color:#475569;line-height:1.6">Use the code below to reset your password. It expires in 1 hour.</p>
<div style="margin:28px 0;padding:24px;background:#f8fafc;border-radius:16px;text-align:center">
  <span style="font-size:36px;font-weight:900;letter-spacing:8px;color:#1e293b">${code}</span>
</div>
<p style="color:#94a3b8;font-size:13px">Enter this code on the password reset page. If you didn't request a reset, you can safely ignore this email.</p>
<p style="margin-top:32px;color:#94a3b8;font-size:13px">— The Foodivo team</p>
</body></html>`;

  try {
    await sendRawEmail(email.trim(), `${code} is your Foodivo reset code`, html);
  } catch (err) {
    console.error("[forgot-password] send error:", err);
    return Response.json({ error: "Failed to send email" }, { status: 500 });
  }

  return Response.json({ ok: true });
}
