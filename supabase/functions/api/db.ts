import { createClient, SupabaseClient } from "./deps.ts";

/// Service-role Postgres client. Used by the function internally (the public
/// anon/user keys can't read PII or sessions directly — RLS denies that).
export function db(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
}
