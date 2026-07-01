import {
  assertEquals,
  assertFalse,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  authorize,
  bearerToken,
  canLead,
  decodeJwt,
  isAuthenticated,
  type JwtClaims,
  type Member,
  requiredAuth,
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
  assertEquals(requiredAuth("participant-lookup"), "public");
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
