// Single routed edge function for DhyanLog. Deployed as `api`; routes live
// under /functions/v1/api/<route>. The hot session buffer is Upstash Redis;
// the only Postgres write is the meditation-stop flush.
import {
  authorize,
  bearerToken,
  decodeJwt,
  devAuthHeartfulnessId,
  isAuthenticated,
  type JwtClaims,
  type Member,
  requiredAuth,
  resolveMemberByEmail,
  resolveOrCreateDevMember,
} from "./auth.ts";
import { Buffer } from "./buffer.ts";
import { listCenters } from "./centers.ts";
import { corsHeaders, json, resolveAllowOrigin } from "./cors.ts";
import { db } from "./db.ts";
import { logRequest } from "./log.ts";
import {
  attend,
  deleteAccount,
  getSession,
  meditationStop,
  sessionHistory,
  sessionRoster,
  startSession,
} from "./handlers.ts";
import { me, requestOtp, verifyOtp } from "./otp.ts";
import { otpRateLimitResponse } from "./ratelimit.ts";

Deno.serve(async (req) => {
  const origin = req.headers.get("Origin");
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        ...corsHeaders,
        "Access-Control-Allow-Origin": resolveAllowOrigin(origin),
      },
    });
  }

  const startedAtMs = Date.now();
  const requestId = crypto.randomUUID();

  // Route = everything after ".../api/".
  const path = new URL(req.url).pathname.replace(/^.*\/api\/?/, "");
  let body: any = {};
  if (req.method === "POST") {
    try {
      body = await req.json();
    } catch {
      body = {};
    }
  }

  // ---- AuthN / AuthZ -------------------------------------------------------
  // The gateway already verified the JWT signature (verify_jwt = true). Here we
  // enforce *who* the caller is: the route's required level, and the caller's
  // role looked up from their verified email (never from client-sent ids).
  const level = requiredAuth(path);
  const token = bearerToken(req);
  let claims: JwtClaims | null = token ? decodeJwt(token) : null;
  let member: Member | null = null;
  // DEV-ONLY bypass (inert unless DEV_AUTH_SECRET is set): trust the caller's
  // Heartfulness ID from the header and synthesize authenticated claims so the
  // normal `authorize` path treats it as a real signed-in member.
  const devHid = level === "public" ? null : devAuthHeartfulnessId(req);
  if (devHid) {
    // Unknown id? Let them in anyway under a generated placeholder (MVP).
    member = await resolveOrCreateDevMember(db(), devHid);
    if (member) {
      claims = {
        role: "authenticated",
        email: `dev+${member.heartfulnessId}`,
        sub: `dev-${member.heartfulnessId}`,
      };
    }
  } else if (level !== "public" && isAuthenticated(claims)) {
    member = await resolveMemberByEmail(db(), claims.email);
  }

  const finish = (resp: Response, error?: string): Response => {
    // Apply the per-request allowed origin centrally (handlers stay origin-agnostic).
    resp.headers.set("Access-Control-Allow-Origin", resolveAllowOrigin(origin));
    logRequest({
      requestId,
      route: path,
      status: resp.status,
      startedAtMs,
      actor: member?.heartfulnessId,
      error,
    });
    return resp;
  };

  const decision = authorize(level, claims, member);
  if (!decision.ok) {
    return finish(json({ error: decision.error }, decision.status));
  }

  try {
    // Throttle the public OTP routes (enumeration / send-spam / code brute-force)
    // before doing any DB or GoTrue work.
    if (path === "auth/request-otp" || path === "auth/verify-otp") {
      const limited = await otpRateLimitResponse(req, path, body);
      if (limited) return finish(limited, "rate_limited");
    }
    switch (path) {
      case "auth/request-otp":
        return finish(await requestOtp(body));
      case "auth/verify-otp":
        return finish(await verifyOtp(body));
      case "auth/me":
        return finish(await me(member!));
      case "sessions/start":
        return finish(await startSession(Buffer.fromEnv(), body, member!));
      case "attend":
        return finish(await attend(Buffer.fromEnv(), body, member!));
      case "sessions/meditation-stop":
        return finish(await meditationStop(Buffer.fromEnv(), body, member!));
      case "sessions/get":
        return finish(await getSession(Buffer.fromEnv(), body));
      case "sessions/attendees":
        return finish(await sessionRoster(Buffer.fromEnv(), body, member!));
      case "centers/list":
        return finish(await listCenters());
      case "sessions/history":
        return finish(await sessionHistory(body, member!));
      case "account/delete": {
        // Delete the app login keyed by the verified `sub` (the auth user id).
        const authUserId = claims?.sub;
        if (!authUserId) {
          return finish(json({ error: "missing subject claim" }, 400));
        }
        return finish(await deleteAccount(authUserId, member!));
      }
      default:
        return finish(json({ error: `unknown route: ${path}` }, 404));
    }
  } catch (e) {
    const message = (e as Error).message;
    return finish(json({ error: message }, 500), message);
  }
});
