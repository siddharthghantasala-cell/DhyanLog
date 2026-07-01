import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { requestLogRecord } from "./log.ts";

Deno.test("requestLogRecord computes latency and info level", () => {
  const record = requestLogRecord({
    requestId: "rid-1",
    route: "sessions/start",
    status: 200,
    startedAtMs: 1_000,
    actor: "HFN-PREC-001",
  }, 1_125);

  assertEquals(record.request_id, "rid-1");
  assertEquals(record.route, "sessions/start");
  assertEquals(record.status, 200);
  assertEquals(record.latency_ms, 125);
  assertEquals(record.level, "info");
  assertEquals(record.actor, "HFN-PREC-001");
});

Deno.test("requestLogRecord marks 5xx as error and omits empty fields", () => {
  const record = requestLogRecord({
    requestId: "rid-2",
    route: "attend",
    status: 500,
    startedAtMs: 0,
  }, 10);

  assertEquals(record.level, "error");
  assertEquals("actor" in record, false); // omitted when absent
  assertEquals("error" in record, false);
});
