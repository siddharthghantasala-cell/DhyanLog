// Single routed edge function for DhyanLog. Deployed as `api`; routes live
// under /functions/v1/api/<route>. The hot session buffer is Upstash Redis;
// the only Postgres write is the meditation-stop flush.
import { Buffer } from "./buffer.ts";
import { corsHeaders, json } from "./cors.ts";
import {
  attend,
  endAttendance,
  getSession,
  lookupParticipant,
  meditationStart,
  meditationStop,
  startSession,
} from "./handlers.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

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

  try {
    switch (path) {
      case "participant-lookup":
        return await lookupParticipant(body);
      case "sessions/start":
        return await startSession(Buffer.fromEnv(), body);
      case "attend":
        return await attend(Buffer.fromEnv(), body);
      case "sessions/end-attendance":
        return await endAttendance(Buffer.fromEnv(), body);
      case "sessions/meditation-start":
        return await meditationStart(Buffer.fromEnv(), body);
      case "sessions/meditation-stop":
        return await meditationStop(Buffer.fromEnv(), body);
      case "sessions/get":
        return await getSession(Buffer.fromEnv(), body);
      default:
        return json({ error: `unknown route: ${path}` }, 404);
    }
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});
