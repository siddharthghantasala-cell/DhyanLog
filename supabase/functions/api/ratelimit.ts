import { Redis } from "./deps.ts";
import { json } from "./cors.ts";

/// Rate limiting for the pre-login OTP routes. These are the only public,
/// unauthenticated routes, so they're the ones an attacker can hammer to
/// enumerate member IDs, spam OTP emails/SMS, or brute-force a code. Backed by
/// the same Upstash Redis as the session buffer (fixed-window counters).

export interface RateLimitRule {
  readonly limit: number;
  readonly windowSeconds: number;
}

// Tunable limits.
//
// Per-ID rules are the real protection: they bound abuse of a *single* member
// (OTP spam, existence probing, code brute-force) and are safe to keep tight
// because GoTrue already spaces sends ~60s apart.
//
// Per-IP rules are a coarse sweep-breaker and are deliberately generous: many
// legitimate members can share one venue/carrier NAT IP, so a tight per-IP cap
// would lock a whole center out of logging in. Raise/lower per deployment.
export const OTP_REQUEST_PER_ID: RateLimitRule = {
  limit: 20,
  windowSeconds: 300,
};
export const OTP_REQUEST_PER_IP: RateLimitRule = {
  limit: 60,
  windowSeconds: 600,
};
export const OTP_VERIFY_PER_ID: RateLimitRule = {
  limit: 6,
  windowSeconds: 600,
};
export const OTP_VERIFY_PER_IP: RateLimitRule = {
  limit: 100,
  windowSeconds: 600,
};

export interface RateLimitResult {
  readonly allowed: boolean;
  readonly retryAfterSeconds: number;
}

/// The subset of Redis the limiter needs. Upstash's client satisfies it; a fake
/// makes the window logic unit-testable without a live connection.
export interface CounterRedis {
  incr(key: string): Promise<number>;
  expire(key: string, seconds: number): Promise<number>;
  ttl(key: string): Promise<number>;
}

/// Best-effort client IP from the forwarded headers Supabase's edge sets. The
/// first hop in `x-forwarded-for` is the caller. Falls back to a constant so a
/// missing header buckets everyone together (fail-safe: still bounded) rather
/// than skipping the limit.
export function clientIp(req: Request): string {
  const xff = req.headers.get("x-forwarded-for");
  if (xff) {
    const first = xff.split(",")[0].trim();
    if (first) return first;
  }
  return req.headers.get("x-real-ip") ?? "unknown";
}

/// The (key, rule) pairs to enforce for an OTP route. Pure, so it's testable
/// without Redis. An empty id contributes no per-id rule (only per-ip applies).
export function otpRules(
  path: string,
  id: string,
  ip: string,
): Array<{ key: string; rule: RateLimitRule }> {
  const isVerify = path === "auth/verify-otp";
  const tag = isVerify ? "vrf" : "req";
  const out: Array<{ key: string; rule: RateLimitRule }> = [];
  if (id) {
    out.push({
      key: `rl:otp:${tag}:id:${id}`,
      rule: isVerify ? OTP_VERIFY_PER_ID : OTP_REQUEST_PER_ID,
    });
  }
  out.push({
    key: `rl:otp:${tag}:ip:${ip}`,
    rule: isVerify ? OTP_VERIFY_PER_IP : OTP_REQUEST_PER_IP,
  });
  return out;
}

export class RateLimiter {
  constructor(private redis: CounterRedis) {}

  static fromEnv(): RateLimiter {
    const url = Deno.env.get("UPSTASH_REDIS_REST_URL");
    const token = Deno.env.get("UPSTASH_REDIS_REST_TOKEN");
    if (!url || !token) {
      throw new Error("UPSTASH_REDIS_REST_URL / _TOKEN not set");
    }
    return new RateLimiter(new Redis({ url, token }));
  }

  /// Fixed-window counter. The first hit in a window sets the TTL; later hits
  /// increment. Fails OPEN on any Redis error — the limiter must never take
  /// sign-in down.
  async check(key: string, rule: RateLimitRule): Promise<RateLimitResult> {
    try {
      const n = await this.redis.incr(key);
      if (n === 1) await this.redis.expire(key, rule.windowSeconds);
      if (n > rule.limit) {
        const ttl = await this.redis.ttl(key);
        return {
          allowed: false,
          retryAfterSeconds: ttl > 0 ? ttl : rule.windowSeconds,
        };
      }
      return { allowed: true, retryAfterSeconds: 0 };
    } catch (_) {
      return { allowed: true, retryAfterSeconds: 0 };
    }
  }
}

/// Enforce the OTP limits for [path], returning a 429 Response if the caller is
/// over any applicable limit, or null to proceed. Fails OPEN if the limiter
/// can't be constructed (e.g. Redis env missing) — never blocks a real user.
export async function otpRateLimitResponse(
  req: Request,
  path: string,
  body: { heartfulnessId?: unknown },
): Promise<Response | null> {
  let limiter: RateLimiter;
  try {
    limiter = RateLimiter.fromEnv();
  } catch (_) {
    return null;
  }
  const id = typeof body.heartfulnessId === "string"
    ? body.heartfulnessId.trim().toUpperCase()
    : "";
  const ip = clientIp(req);
  for (const { key, rule } of otpRules(path, id, ip)) {
    const result = await limiter.check(key, rule);
    if (!result.allowed) {
      const resp = json(
        { error: "Too many attempts. Please wait and try again." },
        429,
      );
      resp.headers.set("Retry-After", String(result.retryAfterSeconds));
      return resp;
    }
  }
  return null;
}
