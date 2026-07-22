import { SupabaseClient } from "./deps.ts";
import { json } from "./cors.ts";
import { db } from "./db.ts";

/// Registered meditation centers. A center owns the capture radius used for its
/// satsangs (see the `check_radius_meters` column), so this is the
/// server-authoritative source of that radius — the client never supplies it.

export interface Center {
  id: string;
  name: string;
  latitude: number;
  longitude: number;
  address: string | null;
  checkRadiusMeters: number;
}

const CENTER_COLUMNS = "id,name,latitude,longitude,address,check_radius_meters";

function toCenter(row: any): Center {
  return {
    id: row.id,
    name: row.name,
    latitude: row.latitude,
    longitude: row.longitude,
    address: row.address ?? null,
    checkRadiusMeters: row.check_radius_meters,
  };
}

/// Resolve a single center by id, or null if it doesn't exist.
export async function getCenter(
  database: SupabaseClient,
  id: string,
): Promise<Center | null> {
  const { data, error } = await database
    .from("meditation_centers")
    .select(CENTER_COLUMNS)
    .eq("id", id)
    .maybeSingle();
  if (error || !data) return null;
  return toCenter(data);
}

/// The list a preceptor picks from when starting a satsang. Names/coords aren't
/// PII, but this is member-gated like the rest of the API.
export async function listCenters(): Promise<Response> {
  const { data, error } = await db()
    .from("meditation_centers")
    .select(CENTER_COLUMNS)
    .order("name", { ascending: true });
  if (error) return json({ error: error.message }, 500);
  return json({ centers: (data ?? []).map(toCenter) });
}
