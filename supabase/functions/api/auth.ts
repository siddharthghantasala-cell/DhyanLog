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
    // History is scoped to the caller's own verified identity inside the
    // handler, so any member may call it.
    case "sessions/history":
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

/// Resolve a member directly by Heartfulness ID. Used ONLY by the dev-auth
/// bypass below — the normal path never trusts a client-sent id.
export async function resolveMemberById(
  db: SupabaseClient,
  heartfulnessId: string,
): Promise<Member | null> {
  const { data, error } = await db
    .from("participants")
    .select("heartfulness_id,role")
    .ilike("heartfulness_id", heartfulnessId)
    .maybeSingle();
  if (error || !data) return null;
  return { heartfulnessId: data.heartfulness_id, role: data.role };
}

/// Infer a placeholder's role from its Heartfulness ID. Ids follow the seed
/// convention (HFN-PREC-xxx, HFN-ABHY-xxx), so a "...PREC..." id becomes a
/// preceptor (can lead sessions) and anything else an abhyasi (attends). This
/// is what lets an unknown tester "have meditation sessions" in either role
/// without a separate toggle.
export function placeholderRole(heartfulnessId: string): string {
  return /prec/i.test(heartfulnessId) ? "preceptor" : "abhyasi";
}

/// DEV-ONLY: resolve the dev-auth member, creating a placeholder participant row
/// if the id is unknown. An unknown id is deliberately let IN (under a generated
/// name) so MVP testers don't need a pre-seeded account.
///
/// The placeholder must be a real row, not just synthesized in memory, because
/// `meditation_sessions.preceptor_id` is a FK to `participants` and `auth/me`
/// reads the row back. The upsert is idempotent, so a repeat login for the same
/// id reuses the existing row. Only ever reached behind the DEV_AUTH_SECRET gate.
export async function resolveOrCreateDevMember(
  db: SupabaseClient,
  heartfulnessId: string,
): Promise<Member | null> {
  const existing = await resolveMemberById(db, heartfulnessId);
  if (existing) return existing;
  const id = heartfulnessId.trim();
  if (!id) return null;
  const { data, error } = await db
    .from("participants")
    .upsert(
      {
        heartfulness_id: id,
        name: `Guest ${id}`,
        age: 0,
        role: placeholderRole(id),
      },
      { onConflict: "heartfulness_id" },
    )
    .select("heartfulness_id,role")
    .maybeSingle();
  if (error || !data) return null;
  return { heartfulnessId: data.heartfulness_id, role: data.role };
}

/// DEV-ONLY sign-in bypass. Returns the Heartfulness ID the caller claims via
/// the `x-dev-hid` header — but ONLY when `DEV_AUTH_SECRET` is set on the
/// function AND the request carries a matching `x-dev-secret` header. This
/// deliberately trades the production identity guarantee (authorize off a
/// verified email, never a client-sent id) for a frictionless MVP login where
/// a member signs in with just their Heartfulness ID.
///
/// It is INERT in production: with no `DEV_AUTH_SECRET` env var set, this always
/// returns null and the normal verified-token path is the only way in.
export function devAuthHeartfulnessId(req: Request): string | null {
  const secret = Deno.env.get("DEV_AUTH_SECRET");
  if (!secret) return null; // dev auth disabled — the prod default
  const provided = req.headers.get("x-dev-secret");
  if (!provided || provided !== secret) return null;
  const hid = (req.headers.get("x-dev-hid") ?? "").trim();
  return hid.length > 0 ? hid : null;
}
