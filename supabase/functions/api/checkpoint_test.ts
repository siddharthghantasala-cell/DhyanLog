import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { metaToRow, rowToMeta } from "./checkpoint.ts";
import { SessionMeta } from "./buffer.ts";

const base: SessionMeta = {
  id: "sess_1",
  preceptorId: "HFN-PREC-001",
  centerId: "CTR-CHN-01",
  latitude: 13.0827,
  longitude: 80.2707,
  startAttendanceAt: "2026-07-01T10:00:00.000Z",
  meditationStartAt: null,
  meditationEndAt: null,
  status: "collecting",
  shortCode: "K7M2PQ",
  frozen: true,
};

Deno.test("metaToRow captures the attendees and count", () => {
  const row = metaToRow(base, ["A", "B", "C"]);
  assertEquals(row.id, "sess_1");
  assertEquals(row.attendee_ids, ["A", "B", "C"]);
  assertEquals(row.attendee_count, 3);
  assertEquals(row.meditation_start_at, null);
});

Deno.test("rowToMeta recovers a collecting (frozen) session", () => {
  const meta = rowToMeta(metaToRow(base, ["A", "B"]));
  assertEquals(meta.id, base.id);
  assertEquals(meta.preceptorId, base.preceptorId);
  assertEquals(meta.frozen, true);
  assertEquals(meta.status, "collecting"); // no meditation start yet
  assertEquals(meta.meditationEndAt, null);
});

Deno.test("rowToMeta marks a session meditating once a start time is set", () => {
  const meditating: SessionMeta = {
    ...base,
    status: "meditating",
    meditationStartAt: "2026-07-01T10:20:00.000Z",
  };
  const meta = rowToMeta(metaToRow(meditating, ["A"]));
  assertEquals(meta.status, "meditating");
  assertEquals(meta.meditationStartAt, "2026-07-01T10:20:00.000Z");
});

Deno.test("meta -> row -> meta preserves ownership + location fields", () => {
  const meta = rowToMeta(metaToRow(base, ["A"]));
  assertEquals(meta.preceptorId, "HFN-PREC-001");
  assertEquals(meta.centerId, "CTR-CHN-01");
  assertEquals(meta.latitude, 13.0827);
  assertEquals(meta.longitude, 80.2707);
  assertEquals(meta.shortCode, "K7M2PQ");
});
