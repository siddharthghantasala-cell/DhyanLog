import { Redis } from "./deps.ts";

/// The hot buffer. A session lives entirely here for its whole life; only the
/// meditation-stop flush writes to Postgres. Keys carry a ~3h TTL as a safety
/// margin over a typical ~1h meditation.
///
/// Matching is kept O(small) without GEOSEARCH by bucketing active sessions
/// into coarse ~11km geo cells; an attend only scans the user's cell + its 8
/// neighbours. Buckets shard the active set so it never becomes a global scan.

export const SESSION_TTL_SECONDS = 3 * 60 * 60;
export const MATCH_RADIUS_METERS = 200;

export interface SessionMeta {
  id: string;
  preceptorId: string;
  centerId: string | null;
  latitude: number;
  longitude: number;
  startAttendanceAt: string; // ISO
  meditationStartAt: string | null;
  meditationEndAt: string | null;
  status: "collecting" | "meditating" | "ended";
  shortCode: string;
  frozen: boolean;
}

const metaKey = (id: string) => `sess:${id}`;
const attKey = (id: string) => `sess:${id}:att`;
const codeKey = (code: string) => `code:${code.toUpperCase()}`;
const cellKey = (b: string) => `cell:${b}`;

function bucketOf(lat: number, lng: number): string {
  return `${Math.round(lat * 10)}:${Math.round(lng * 10)}`;
}

function neighbourBuckets(lat: number, lng: number): string[] {
  const la = Math.round(lat * 10);
  const lo = Math.round(lng * 10);
  const out: string[] = [];
  for (let i = -1; i <= 1; i++) {
    for (let j = -1; j <= 1; j++) out.push(`${la + i}:${lo + j}`);
  }
  return out;
}

export function distanceMeters(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const R = 6371000;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export class Buffer {
  constructor(private redis: Redis) {}

  static fromEnv(): Buffer {
    const url = Deno.env.get("UPSTASH_REDIS_REST_URL");
    const token = Deno.env.get("UPSTASH_REDIS_REST_TOKEN");
    if (!url || !token) {
      throw new Error("UPSTASH_REDIS_REST_URL / _TOKEN not set");
    }
    return new Buffer(new Redis({ url, token }));
  }

  async createSession(meta: SessionMeta): Promise<void> {
    const bucket = bucketOf(meta.latitude, meta.longitude);
    await Promise.all([
      this.redis.set(metaKey(meta.id), JSON.stringify(meta), {
        ex: SESSION_TTL_SECONDS,
      }),
      this.redis.set(codeKey(meta.shortCode), meta.id, {
        ex: SESSION_TTL_SECONDS,
      }),
      this.redis.sadd(cellKey(bucket), meta.id),
      this.redis.expire(cellKey(bucket), SESSION_TTL_SECONDS),
    ]);
  }

  async getMeta(id: string): Promise<SessionMeta | null> {
    const raw = await this.redis.get<string | SessionMeta>(metaKey(id));
    if (!raw) return null;
    // Upstash may auto-deserialize JSON depending on stored type.
    return typeof raw === "string"
      ? (JSON.parse(raw) as SessionMeta)
      : (raw as SessionMeta);
  }

  async putMeta(meta: SessionMeta): Promise<void> {
    await this.redis.set(metaKey(meta.id), JSON.stringify(meta), {
      ex: SESSION_TTL_SECONDS,
      xx: true,
    });
  }

  /// SADD-equivalent. Returns true if newly added, false if already present.
  async addAttendee(id: string, heartfulnessId: string): Promise<boolean> {
    const added = await this.redis.sadd(attKey(id), heartfulnessId);
    await this.redis.expire(attKey(id), SESSION_TTL_SECONDS);
    return added === 1;
  }

  async attendees(id: string): Promise<string[]> {
    return (await this.redis.smembers(attKey(id))) ?? [];
  }

  async count(id: string): Promise<number> {
    return (await this.redis.scard(attKey(id))) ?? 0;
  }

  async resolveCode(code: string): Promise<string | null> {
    return await this.redis.get<string>(codeKey(code));
  }

  /// Active, collecting, unfrozen sessions within range of a point.
  async findNearby(lat: number, lng: number): Promise<SessionMeta[]> {
    const buckets = neighbourBuckets(lat, lng);
    const idLists = await Promise.all(
      buckets.map((b) => this.redis.smembers(cellKey(b))),
    );
    const ids = [...new Set(idLists.flat().filter(Boolean))] as string[];
    const metas = await Promise.all(ids.map((id) => this.getMeta(id)));
    const now = Date.now();
    const out: SessionMeta[] = [];
    for (const m of metas) {
      if (!m || m.frozen || m.status !== "collecting") continue;
      if (now - Date.parse(m.startAttendanceAt) > SESSION_TTL_SECONDS * 1000) {
        continue;
      }
      if (distanceMeters(lat, lng, m.latitude, m.longitude) <= MATCH_RADIUS_METERS) {
        out.push(m);
      }
    }
    return out;
  }

  /// Evict a finalized session from the buffer (post-flush).
  async evict(meta: SessionMeta): Promise<void> {
    const bucket = bucketOf(meta.latitude, meta.longitude);
    await Promise.all([
      this.redis.del(metaKey(meta.id)),
      this.redis.del(attKey(meta.id)),
      this.redis.del(codeKey(meta.shortCode)),
      this.redis.srem(cellKey(bucket), meta.id),
    ]);
  }
}
