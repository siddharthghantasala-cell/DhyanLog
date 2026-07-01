import { SupabaseClient } from "./deps.ts";

/// How much authority a route requires.
///  - public: no identity (used pre-login, e.g. participant lookup)
///  - member: any authenticated Heartfulness member
///  - leader: a preceptor or master
export type AuthLevel = "public" | "member" | "leader";

export interface Member {
  heartfulnessId: string;
  role: string; // 'abhyasi' | 'preceptor' | 'master'
}

export interface JwtClaims {
  sub?: string;
  role?: string; // 'anon' (anon key) | 'authenticated' (a real user)
  email?: string;
}

const LEADER_ROLES = new Set(["preceptor", "master"]);
export function canLead(role: string): boolean {
  return LEADER_ROLES.has(role);
}

export function bearerToken(req: Request): string | null {
  const header = req.headers.get("Authorization") ?? "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match ? match[1].trim() : null;
}

function base64UrlToString(segment: string): string {
  const pad = (4 - (segment.length % 4)) % 4;
  const b64 = segment.replace(/-/g, "+").replace(/_/g, "/") + "=".repeat(pad);
  const binary = atob(b64);
  const bytes = Uint8Array.from(binary, (c) => c.charCodeAt(0));
  return new TextDecoder().decode(bytes);
}

/// Decode a JWT's payload. The Supabase gateway already verified the signature
/// (`verify_jwt = true`), so the claims here can be trusted; we only need to
/// read them. Returns null for a malformed token.
export function decodeJwt(token: string): JwtClaims | null {
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  try {
    return JSON.parse(base64UrlToString(parts[1])) as JwtClaims;
  } catch {
    return null;
  }
}

/// True only for a real signed-in user (the anon key has role 'anon' and no
/// email). The `email` claim is GoTrue-managed and not user-forgeable, which is
/// why we key identity off it rather than the user-writable user_metadata.
export function isAuthenticated(
  claims: JwtClaims | null,
): claims is JwtClaims & { email: string } {
  return !!claims &&
    claims.role === "authenticated" &&
    typeof claims.email === "string" &&
    claims.email.length > 0;
}

export function requiredAuth(route: string): AuthLevel {
  switch (route) {
    // Pre-login OTP flow. These are public because the caller isn't
    // authenticated yet, but they never expose PII: the member's contact is
    // resolved and used entirely server-side; only a masked hint is returned.
    case "auth/request-otp":
    case "auth/verify-otp":
      return "public";
    case "sessions/start":
    case "sessions/end-attendance":
    case "sessions/meditation-start":
    case "sessions/meditation-stop":
      return "leader";
    case "auth/me":
    case "attend":
    case "sessions/get":
    case "account/delete":
      return "member";
    default:
      return "member";
  }
}

/// Pure authorization decision given the (already trusted) claims and the member
/// resolved from them. Separated out so it's unit-testable without a DB.
export function authorize(
  level: AuthLevel,
  claims: JwtClaims | null,
  member: Member | null,
): { ok: boolean; status: number; error?: string } {
  if (level === "public") return { ok: true, status: 200 };
  if (!isAuthenticated(claims)) {
    return { ok: false, status: 401, error: "authentication required" };
  }
  if (!member) {
    return { ok: false, status: 403, error: "not a recognized member" };
  }
  if (level === "leader" && !canLead(member.role)) {
    return { ok: false, status: 403, error: "preceptor role required" };
  }
  return { ok: true, status: 200 };
}

/// Resolve the member behind a verified email. Ambiguous (>1 row) or unknown
/// emails resolve to null → treated as "not a recognized member".
export async function resolveMemberByEmail(
  db: SupabaseClient,
  email: string,
): Promise<Member | null> {
  const { data, error } = await db
    .from("participants")
    .select("heartfulness_id,role")
    .eq("email", email.toLowerCase())
    .maybeSingle();
  if (error || !data) return null;
  return { heartfulnessId: data.heartfulness_id, role: data.role };
}
