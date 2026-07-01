import { createClient, SupabaseClient } from "./deps.ts";
import { type Member } from "./auth.ts";
import { json } from "./cors.ts";
import { db } from "./db.ts";
import { cleanString } from "./validation.ts";

/// Server-side OTP sign-in. The whole point of this module is that the member's
/// email/phone is resolved and used entirely on the server: the client sends
/// only a Heartfulness ID and a code, and never receives the raw contact. This
/// replaces the old anon-readable `participant-lookup`, which leaked member PII
/// before login.

interface ParticipantRow {
  heartfulness_id: string;
  name: string;
  age: number;
  address: string | null;
  email: string | null;
  phone: string | null;
  role: string;
}

const PARTICIPANT_COLUMNS = "heartfulness_id,name,age,address,email,phone,role";

/// Anon GoTrue client for sending/verifying OTPs. Never persists a session — it
/// is created fresh per request and only used to drive the OTP exchange.
function authClient(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
}

function isEmail(contact: string): boolean {
  return contact.includes("@");
}

/// The member's login contact: email if present, else phone.
function pickContact(row: ParticipantRow): string {
  const email = (row.email ?? "").trim();
  if (email) return email;
  return (row.phone ?? "").trim();
}

/// Privacy-safe hint shown to the user (`a***@domain` / `***1234`). Mirrors the
/// Dart `maskContact` so the displayed hint is identical wherever it's computed.
export function maskContact(contact: string): string {
  const c = contact.trim();
  if (!c) return "";
  if (isEmail(c)) {
    const [local, domain] = c.split("@");
    return `${local.slice(0, 1)}***@${domain}`;
  }
  const digits = c.replace(/\D/g, "");
  return `***${digits.slice(-4)}`;
}

async function getParticipant(
  heartfulnessId: string,
): Promise<ParticipantRow | null> {
  const { data } = await db()
    .from("participants")
    .select(PARTICIPANT_COLUMNS)
    .ilike("heartfulness_id", heartfulnessId)
    .maybeSingle();
  return (data as ParticipantRow | null) ?? null;
}

/// Step 1: resolve the member's contact server-side and send a one-time code to
/// it. Only a masked hint is ever returned — the raw email/phone never leaves
/// the server.
export async function requestOtp(body: any): Promise<Response> {
  const id = cleanString(body.heartfulnessId, 128);
  if (!id) return json({ error: "heartfulnessId required" }, 400);
  const row = await getParticipant(id);
  if (!row) return json({ error: "No Heartfulness member found." }, 404);
  const contact = pickContact(row);
  if (!contact) {
    return json({ error: "No email or phone on file for this member." }, 422);
  }

  const auth = authClient();
  const data = { heartfulness_id: row.heartfulness_id };
  const { error } = isEmail(contact)
    ? await auth.auth.signInWithOtp({ email: contact, options: { data } })
    : await auth.auth.signInWithOtp({
      phone: contact.replace(/\s/g, ""),
      options: { data },
    });
  if (error) return json({ error: "Could not send a code." }, 502);
  return json({ masked: maskContact(contact) });
}

/// Step 2: verify the code server-side. On success, links the auth user to the
/// member (service-role metadata write) and returns the new session tokens plus
/// the member's own record — safe to return now that they've proven they
/// control the contact.
export async function verifyOtp(body: any): Promise<Response> {
  const id = cleanString(body.heartfulnessId, 128);
  const code = cleanString(body.code, 12);
  if (!id || !code) {
    return json({ error: "heartfulnessId and code required" }, 400);
  }
  const row = await getParticipant(id);
  if (!row) return json({ error: "No Heartfulness member found." }, 404);
  const contact = pickContact(row);
  if (!contact) return json({ error: "No contact on file." }, 422);

  const auth = authClient();
  const { data, error } = isEmail(contact)
    ? await auth.auth.verifyOtp({ email: contact, token: code, type: "email" })
    : await auth.auth.verifyOtp({
      phone: contact.replace(/\s/g, ""),
      token: code,
      type: "sms",
    });
  const session = data?.session;
  if (error || !session) {
    return json({ error: "That code did not work." }, 401);
  }
  // Link the auth user to the member so a restart can re-resolve identity.
  // Best-effort: sign-in already succeeded, so don't fail on a metadata hiccup.
  await db().auth.admin.updateUserById(session.user.id, {
    user_metadata: { heartfulness_id: row.heartfulness_id },
  });
  return json({
    access_token: session.access_token,
    refresh_token: session.refresh_token,
    participant: row,
  });
}

/// The caller's own participant record, resolved from their verified identity.
/// Replaces the public participant-lookup for session restore: a member can only
/// fetch themselves, and only while authenticated.
export async function me(member: Member): Promise<Response> {
  const row = await getParticipant(member.heartfulnessId);
  if (!row) return json({ error: "not found" }, 404);
  return json({ participant: row });
}
