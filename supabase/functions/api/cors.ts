export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
  "Vary": "Origin",
};

/// Resolve the Access-Control-Allow-Origin for a request. With `ALLOWED_ORIGINS`
/// set (comma-separated), only those origins are reflected back; an unlisted
/// origin gets the first allowed one (so the browser blocks it). Unset (dev)
/// falls back to `*`. Applied centrally in index.ts so handler responses don't
/// each need the request origin.
export function resolveAllowOrigin(requestOrigin: string | null): string {
  const allowed = (Deno.env.get("ALLOWED_ORIGINS") ?? "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  if (allowed.length === 0) return "*";
  if (requestOrigin && allowed.includes(requestOrigin)) return requestOrigin;
  return allowed[0];
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
