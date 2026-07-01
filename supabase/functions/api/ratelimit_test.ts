import {
  assertEquals,
  assertFalse,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  clientIp,
  type CounterRedis,
  OTP_REQUEST_PER_ID,
  otpRules,
  RateLimiter,
} from "./ratelimit.ts";

/// In-memory fixed-window counter standing in for Upstash Redis.
class FakeRedis implements CounterRedis {
  counts = new Map<string, number>();
  ttls = new Map<string, number>();

  incr(key: string): Promise<number> {
    const n = (this.counts.get(key) ?? 0) + 1;
    this.counts.set(key, n);
    return Promise.resolve(n);
  }
  expire(key: string, seconds: number): Promise<number> {
    this.ttls.set(key, seconds);
    return Promise.resolve(1);
  }
  ttl(key: string): Promise<number> {
    return Promise.resolve(this.ttls.get(key) ?? -1);
  }
}

Deno.test("clientIp takes the first x-forwarded-for hop", () => {
  const req = new Request("https://x/api", {
    headers: { "x-forwarded-for": "203.0.113.7, 10.0.0.1" },
  });
  assertEquals(clientIp(req), "203.0.113.7");
});

Deno.test("clientIp falls back to a constant when unknown", () => {
  assertEquals(clientIp(new Request("https://x/api")), "unknown");
});

Deno.test("otpRules: request path uses request rules + per-ip", () => {
  const rules = otpRules("auth/request-otp", "HFN-PREC-001", "1.2.3.4");
  assertEquals(rules.length, 2);
  assertEquals(rules[0].key, "rl:otp:req:id:HFN-PREC-001");
  assertEquals(rules[1].key, "rl:otp:req:ip:1.2.3.4");
});

Deno.test("otpRules: verify path is tagged separately", () => {
  const rules = otpRules("auth/verify-otp", "HFN-PREC-001", "1.2.3.4");
  assertEquals(rules[0].key, "rl:otp:vrf:id:HFN-PREC-001");
  assertEquals(rules[1].key, "rl:otp:vrf:ip:1.2.3.4");
});

Deno.test("otpRules: an empty id contributes only the per-ip rule", () => {
  const rules = otpRules("auth/request-otp", "", "1.2.3.4");
  assertEquals(rules.length, 1);
  assertEquals(rules[0].key, "rl:otp:req:ip:1.2.3.4");
});

Deno.test("RateLimiter allows up to the limit, then blocks", async () => {
  const limiter = new RateLimiter(new FakeRedis());
  const rule = OTP_REQUEST_PER_ID; // limit 3
  for (let i = 0; i < rule.limit; i++) {
    const r = await limiter.check("k", rule);
    assertEquals(r.allowed, true);
  }
  const blocked = await limiter.check("k", rule);
  assertFalse(blocked.allowed);
  assertEquals(blocked.retryAfterSeconds, rule.windowSeconds);
});

Deno.test("RateLimiter sets the TTL only on the first hit", async () => {
  const redis = new FakeRedis();
  const limiter = new RateLimiter(redis);
  await limiter.check("k", OTP_REQUEST_PER_ID);
  await limiter.check("k", OTP_REQUEST_PER_ID);
  assertEquals(redis.counts.get("k"), 2);
  assertEquals(redis.ttls.get("k"), OTP_REQUEST_PER_ID.windowSeconds);
});

Deno.test("RateLimiter fails open on a Redis error", async () => {
  const throwing: CounterRedis = {
    incr: () => Promise.reject(new Error("down")),
    expire: () => Promise.resolve(1),
    ttl: () => Promise.resolve(-1),
  };
  const r = await new RateLimiter(throwing).check("k", OTP_REQUEST_PER_ID);
  assertEquals(r.allowed, true);
});
