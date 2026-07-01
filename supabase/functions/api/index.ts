// Single routed edge function for DhyanLog. Deployed as `api`; routes live
// under /functions/v1/api/<route>. The hot session buffer is Upstash Redis;
// the only Postgres write is the meditation-stop flush.
import {
  authorize,
  bearerToken,
  decodeJwt,
  isAuthenticated,
  type Member,
  requiredAuth,
  resolveMemberByEmail,
} from "./auth.ts";
import { Buffer } from "./buffer.ts";
import { corsHeaders, json, resolveAllowOrigin } from "./cors.ts";
import { db } from "./db.ts";
import { logRequest } from "./log.ts";
import {
  attend,
  deleteAccount,
  endAttendance,
  getSession,
  meditationStart,
  meditationStop,
  startSession,
} from "./handlers.ts";
import { me, requestOtp, verifyOtp } from "./otp.ts";

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
  const claims = token ? decodeJwt(token) : null;
  let member: Member | null = null;
  if (level !== "public" && isAuthenticated(claims)) {
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
      case "sessions/end-attendance":
        return finish(await endAttendance(Buffer.fromEnv(), body, member!));
      case "sessions/meditation-start":
        return finish(await meditationStart(Buffer.fromEnv(), body, member!));
      case "sessions/meditation-stop":
        return finish(await meditationStop(Buffer.fromEnv(), body, member!));
      case "sessions/get":
        return finish(await getSession(Buffer.fromEnv(), body));
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
