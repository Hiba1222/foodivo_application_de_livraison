import { createServerClient, type CookieOptions } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

// Which top-level route prefix each role is allowed into.
const ROLE_HOME: Record<string, string> = {
  admin: "/admin",
  restaurant_owner: "/restaurant",
  client: "/client",
  driver: "/driver",
};

export async function middleware(request: NextRequest) {
  let response = NextResponse.next({ request: { headers: request.headers } });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        get(name: string) {
          return request.cookies.get(name)?.value;
        },
        set(name: string, value: string, options: CookieOptions) {
          response.cookies.set({ name, value, ...options });
        },
        remove(name: string, options: CookieOptions) {
          response.cookies.set({ name, value: "", ...options });
        },
      },
    }
  );

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const path = request.nextUrl.pathname;
  const isPublic =
    path === "/login" || path === "/signup" || path === "/" ||
    path === "/forgot-password" || path === "/reset-password" ||
    path.startsWith("/_next");

  // Not logged in and hitting a protected route -> send to login.
  if (!user && !isPublic) {
    return NextResponse.redirect(new URL("/login", request.url));
  }

  if (user) {
    const { data: profile } = await supabase
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .single();

    const role = profile?.role as keyof typeof ROLE_HOME | undefined;
    const home = role ? ROLE_HOME[role] : undefined;

    // Logged in, visiting /login or /signup -> bounce straight to their dashboard.
    if ((path === "/login" || path === "/signup") && home) {
      return NextResponse.redirect(new URL(home, request.url));
    }

    // Logged in but trying to access a different role's section.
    const matchedPrefix = Object.values(ROLE_HOME).find((prefix) =>
      path.startsWith(prefix)
    );
    if (matchedPrefix && matchedPrefix !== home) {
      return NextResponse.redirect(new URL("/unauthorized", request.url));
    }
  }

  return response;
}

export const config = {
  // Skip static files (logo, icons, images in /public) so they load on the login page too.
  matcher: [
    "/((?!api|_next/static|_next/image|favicon.ico|.*\\.(?:png|jpg|jpeg|gif|svg|webp|ico|txt|xml)$).*)",
  ],
};
