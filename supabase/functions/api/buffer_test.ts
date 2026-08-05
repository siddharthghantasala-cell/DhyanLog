import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { Buffer, SessionMeta } from "./buffer.ts";

/// Minimal in-memory stand-in for the Upstash Redis client — only the handful
/// of operations createSession + findNearby touch.
class FakeRedis {
  store = new Map<string, string>();
  sets = new Map<string, Set<string>>();
  // deno-lint-ignore no-explicit-any
  async set(k: string, v: string, _opts?: any) {
    this.store.set(k, v);
  }
  async get<T>(k: string): Promise<T | null> {
    return (this.store.get(k) ?? null) as T | null;
  }
  async sadd(k: string, ...members: string[]) {
    const s = this.sets.get(k) ?? new Set<string>();
    const before = s.size;
    for (const m of members) s.add(m);
    this.sets.set(k, s);
    return s.size - before;
  }
  async smembers(k: string) {
    return [...(this.sets.get(k) ?? [])];
  }
  async expire() {}
}

function meta(overrides: Partial<SessionMeta>): SessionMeta {
  return {
    id: "sess_x",
    preceptorId: "HFN-PREC-001",
    centerId: null,
    latitude: 13.0827,
    longitude: 80.2707,
    startAttendanceAt: new Date().toISOString(),
    meditationStartAt: new Date().toISOString(),
    meditationEndAt: null,
    status: "meditating",
    shortCode: "AAAA11",
    frozen: false,
    type: "regular",
    matchRadiusMeters: 30,
    ...overrides,
  };
}

function buffer() {
  return new Buffer(new FakeRedis() as unknown as never);
}

// ~500m north of the Chennai anchor.
const near = { lat: 13.0827 + 500 / 111320, lng: 80.2707 };

Deno.test("findNearby: a wide satsang captures a far attendee", async () => {
  const buf = buffer();
  await buf.createSession(
    meta({ id: "satsang", type: "satsang", matchRadiusMeters: 2000 }),
  );
  const hits = await buf.findNearby(near.lat, near.lng);
  assertEquals(hits.map((m) => m.id), ["satsang"]);
});

Deno.test("findNearby: a tight regular session rejects the same far attendee", async () => {
  const buf = buffer();
  await buf.createSession(
    meta({ id: "regular", type: "regular", matchRadiusMeters: 30 }),
  );
  const hits = await buf.findNearby(near.lat, near.lng);
  assertEquals(hits, []);
});

Deno.test("findNearby: only the session whose radius reaches matches", async () => {
  const buf = buffer();
  await buf.createSession(
    meta({ id: "satsang", type: "satsang", matchRadiusMeters: 2000 }),
  );
  await buf.createSession(
    meta({ id: "regular", type: "regular", matchRadiusMeters: 30 }),
  );
  const hits = await buf.findNearby(near.lat, near.lng);
  assertEquals(hits.map((m) => m.id), ["satsang"]);
});

Deno.test("findNearby: a co-located attendee joins even a tight regular", async () => {
  const buf = buffer();
  await buf.createSession(meta({ id: "regular", matchRadiusMeters: 30 }));
  const hits = await buf.findNearby(13.0827, 80.2707); // exact anchor
  assertEquals(hits.map((m) => m.id), ["regular"]);
});
