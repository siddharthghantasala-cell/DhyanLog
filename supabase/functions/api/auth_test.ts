import {
  assertEquals,
  assertFalse,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  authorize,
  bearerToken,
  canLead,
  decodeJwt,
  devAuthHeartfulnessId,
  isAuthenticated,
  type JwtClaims,
  type Member,
  placeholderRole,
  requiredAuth,
  resolveOrCreateDevMember,
} from "./auth.ts";

function makeJwt(payload: Record<string, unknown>): string {
  const b64url = (obj: unknown) =>
    btoa(JSON.stringify(obj)).replace(/\+/g, "-").replace(/\//g, "_").replace(
      /=+$/,
      "",
    );
  return `${b64url({ alg: "HS256" })}.${b64url(payload)}.sig`;
}

const preceptor: Member = { heartfulnessId: "HFN-PREC-001", role: "preceptor" };
const abhyasi: Member = { heartfulnessId: "HFN-ABHY-001", role: "abhyasi" };
const master: Member = { heartfulnessId: "HFN-MASTER-000", role: "master" };

Deno.test("bearerToken extracts the token, else null", () => {
  const req = (auth?: string) =>
    new Request("https://x/api", {
      headers: auth ? { Authorization: auth } : {},
    });
  assertEquals(bearerToken(req("Bearer abc.def.ghi")), "abc.def.ghi");
  assertEquals(bearerToken(req("bearer xyz")), "xyz"); // case-insensitive
  assertEquals(bearerToken(req()), null);
});

Deno.test("decodeJwt reads claims and rejects malformed", () => {
  const token = makeJwt({ role: "authenticated", email: "a@b.org", sub: "u1" });
  const claims = decodeJwt(token);
  assertEquals(claims?.role, "authenticated");
  assertEquals(claims?.email, "a@b.org");
  assertEquals(decodeJwt("not-a-jwt"), null);
  assertEquals(decodeJwt("only.two"), null);
});

Deno.test("isAuthenticated only for a real user with an email", () => {
  const user: JwtClaims = { role: "authenticated", email: "a@b.org" };
  const anon: JwtClaims = { role: "anon" };
  assertEquals(isAuthenticated(user), true);
  assertFalse(isAuthenticated(anon));
  assertFalse(isAuthenticated({ role: "authenticated" })); // no email
  assertFalse(isAuthenticated(null));
});

Deno.test("canLead is preceptor/master only", () => {
  assertEquals(canLead("preceptor"), true);
  assertEquals(canLead("master"), true);
  assertFalse(canLead("abhyasi"));
});

Deno.test("requiredAuth maps routes to levels", () => {
  assertEquals(requiredAuth("auth/request-otp"), "public");
  assertEquals(requiredAuth("auth/verify-otp"), "public");
  assertEquals(requiredAuth("auth/me"), "member");
  assertEquals(requiredAuth("attend"), "member");
  assertEquals(requiredAuth("sessions/get"), "member");
  assertEquals(requiredAuth("sessions/start"), "leader");
  assertEquals(requiredAuth("sessions/meditation-stop"), "leader");
  assertEquals(requiredAuth("account/delete"), "member");
});

Deno.test("authorize: public needs nothing", () => {
  assertEquals(authorize("public", null, null).ok, true);
});

Deno.test("authorize: member rejects anon and unknown, accepts known", () => {
  const anon: JwtClaims = { role: "anon" };
  const user: JwtClaims = { role: "authenticated", email: "a@b.org" };
  assertEquals(authorize("member", anon, null).status, 401);
  assertEquals(authorize("member", user, null).status, 403); // not a member
  assertEquals(authorize("member", user, abhyasi).ok, true);
});

Deno.test("authorize: leader requires a leading role", () => {
  const user: JwtClaims = { role: "authenticated", email: "a@b.org" };
  assertEquals(authorize("leader", user, abhyasi).status, 403);
  assertEquals(authorize("leader", user, preceptor).ok, true);
  assertEquals(authorize("leader", user, master).ok, true);
});

Deno.test("placeholderRole: PREC ids lead, everything else attends", () => {
  assertEquals(placeholderRole("HFN-PREC-999"), "preceptor");
  assertEquals(placeholderRole("hfn-prec-042"), "preceptor"); // case-insensitive
  assertEquals(placeholderRole("HFN-ABHY-999"), "abhyasi");
  assertEquals(placeholderRole("random-guest"), "abhyasi");
});

/// Minimal fluent stand-in for the participants table: supports the
/// select/ilike/maybeSingle read and the upsert/select/maybeSingle write that
/// resolveOrCreateDevMember drives. Keyed case-insensitively, like the real ilike.
function fakeDb(seed: Array<{ heartfulness_id: string; role: string }> = []) {
  const rows = new Map<string, { heartfulness_id: string; role: string }>();
  for (const r of seed) rows.set(r.heartfulness_id.toLowerCase(), r);
  const builder = () => {
    let pending: { heartfulness_id: string; role: string } | null = null;
    const api: Record<string, unknown> = {
      select: () => api,
      ilike: (_col: string, val: string) => {
        pending = rows.get(val.toLowerCase()) ?? null;
        return api;
      },
      // deno-lint-ignore no-explicit-any
      upsert: (row: any) => {
        const stored = { heartfulness_id: row.heartfulness_id, role: row.role };
        rows.set(row.heartfulness_id.toLowerCase(), stored);
        pending = stored;
        return api;
      },
      maybeSingle: () => Promise.resolve({ data: pending, error: null }),
    };
    return api;
  };
  return { from: builder, rows } as never;
}

Deno.test("resolveOrCreateDevMember: returns an existing member unchanged", async () => {
  const db = fakeDb([{ heartfulness_id: "HFN-ABHY-001", role: "abhyasi" }]);
  const m = await resolveOrCreateDevMember(db, "hfn-abhy-001"); // any case
  assertEquals(m, { heartfulnessId: "HFN-ABHY-001", role: "abhyasi" });
});

Deno.test("resolveOrCreateDevMember: creates a placeholder for an unknown id", async () => {
  const db = fakeDb();
  const m = await resolveOrCreateDevMember(db, "HFN-PREC-777");
  assertEquals(m, { heartfulnessId: "HFN-PREC-777", role: "preceptor" });
  // Idempotent: a second login reuses the row rather than duplicating it.
  const again = await resolveOrCreateDevMember(db, "HFN-PREC-777");
  assertEquals(again, m);
});

Deno.test("resolveOrCreateDevMember: an unknown non-PREC id becomes an abhyasi", async () => {
  const db = fakeDb();
  const m = await resolveOrCreateDevMember(db, "curious-visitor");
  assertEquals(m?.role, "abhyasi");
});

Deno.test("resolveOrCreateDevMember: a blank id is rejected", async () => {
  const db = fakeDb();
  assertEquals(await resolveOrCreateDevMember(db, "   "), null);
});

Deno.test("devAuthHeartfulnessId: inert unless DEV_AUTH_SECRET is set", () => {
  Deno.env.delete("DEV_AUTH_SECRET");
  const req = new Request("https://x/api/sessions/start", {
    headers: { "x-dev-secret": "s3cret", "x-dev-hid": "HFN-ABHY-001" },
  });
  assertEquals(devAuthHeartfulnessId(req), null);
});

Deno.test("devAuthHeartfulnessId: needs a matching secret + non-empty id", () => {
  Deno.env.set("DEV_AUTH_SECRET", "s3cret");
  try {
    // Wrong secret -> rejected.
    assertEquals(
      devAuthHeartfulnessId(
        new Request("https://x/api/sessions/start", {
          headers: { "x-dev-secret": "nope", "x-dev-hid": "HFN-ABHY-001" },
        }),
      ),
      null,
    );
    // No id -> rejected even with the right secret.
    assertEquals(
      devAuthHeartfulnessId(
        new Request("https://x/api/sessions/start", {
          headers: { "x-dev-secret": "s3cret" },
        }),
      ),
      null,
    );
    // Right secret + id -> trusted, trimmed.
    assertEquals(
      devAuthHeartfulnessId(
        new Request("https://x/api/sessions/start", {
          headers: { "x-dev-secret": "s3cret", "x-dev-hid": " HFN-ABHY-001 " },
        }),
      ),
      "HFN-ABHY-001",
    );
  } finally {
    Deno.env.delete("DEV_AUTH_SECRET");
  }
});
